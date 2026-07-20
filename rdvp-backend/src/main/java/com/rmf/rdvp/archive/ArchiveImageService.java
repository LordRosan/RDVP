package com.rmf.rdvp.archive;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.Base64;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Pattern;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageOutputStream;
import javax.imageio.stream.ImageInputStream;

import org.springframework.stereotype.Service;

import com.rmf.rdvp.shared.error.BusinessException;
import com.rmf.rdvp.shared.error.ErrorCode;

@Service
public class ArchiveImageService {

    private static final Pattern IMAGE_ID_PATTERN = Pattern.compile("^[A-Za-z0-9_-]{1,64}$");
    private static final int MAX_IMAGES = 5;
    private static final int MAX_IMAGE_BYTES = 1_500_000;
    private static final int MAX_IMAGE_EDGE = 1600;
    private static final int THUMBNAIL_EDGE = 240;

    private final ArchiveImageRepository imageRepository;
    private final ArchiveRequestImageRepository requestImageRepository;

    public ArchiveImageService(
            ArchiveImageRepository imageRepository,
            ArchiveRequestImageRepository requestImageRepository) {
        this.imageRepository = imageRepository;
        this.requestImageRepository = requestImageRepository;
    }

    public List<ArchiveImage> findByDeviceId(String deviceId) {
        return imageRepository.findByDeviceId(deviceId);
    }

    public ArchiveImage findById(String imageId) {
        if (imageId == null || !IMAGE_ID_PATTERN.matcher(imageId.trim()).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "imageId is invalid.");
        }
        return imageRepository.findById(imageId.trim())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
    }

    public Optional<List<ArchiveImage>> prepareChange(
            String deviceId,
            List<ArchiveImageSubmission> submissions) {
        if (submissions == null) {
            return Optional.empty();
        }
        if (submissions.size() > MAX_IMAGES) {
            throw invalidImage("An archive can contain at most five images.");
        }

        List<ArchiveImage> images = java.util.stream.IntStream.range(0, submissions.size())
                .mapToObj(index -> prepareImage(deviceId, submissions.get(index), index))
                .toList();
        long distinctImageIds = images.stream().map(ArchiveImage::id).distinct().count();
        if (distinctImageIds != images.size()) {
            throw invalidImage("An archive image cannot be selected more than once.");
        }
        return Optional.of(images);
    }

    public void savePendingChange(String requestId, List<ArchiveImage> images) {
        requestImageRepository.saveChange(requestId, images);
    }

    public Optional<List<ArchiveImage>> findPendingChange(String requestId) {
        return requestImageRepository.findChangeByRequestId(requestId);
    }

    public Map<String, List<ArchiveImage>> findPendingSummaryChanges(List<String> requestIds) {
        return requestImageRepository.findSummaryChangesByRequestIds(requestIds);
    }

    public ArchiveImage findPendingImage(String requestId, String imageId) {
        if (requestId == null || imageId == null
                || !IMAGE_ID_PATTERN.matcher(requestId.trim()).matches()
                || !IMAGE_ID_PATTERN.matcher(imageId.trim()).matches()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST);
        }
        return requestImageRepository.findByRequestIdAndImageId(requestId.trim(), imageId.trim())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND));
    }

    public void applyPendingChange(String requestId, String deviceId, String operatorId) {
        requestImageRepository.findChangeByRequestId(requestId).ifPresent(images -> {
            List<ArchiveImage> formalImages = java.util.stream.IntStream.range(0, images.size())
                    .mapToObj(index -> copyForArchive(images.get(index), deviceId, index))
                    .toList();
            imageRepository.replaceForDevice(deviceId, formalImages, operatorId);
        });
    }

    private ArchiveImage prepareImage(String deviceId, ArchiveImageSubmission submission, int sortOrder) {
        if (submission == null) {
            throw invalidImage("Image payload is required.");
        }
        String existingId = normalize(submission.id());
        String contentBase64 = normalize(submission.contentBase64());
        if (existingId.isBlank() == contentBase64.isBlank()) {
            throw invalidImage("Provide either an existing image id or image content.");
        }

        if (!existingId.isBlank()) {
            ArchiveImage existing = findById(existingId);
            if (deviceId == null || !deviceId.equals(existing.deviceId())) {
                throw invalidImage("Existing image does not belong to this archive.");
            }
            return new ArchiveImage(
                    existing.id(), deviceId, sortOrder, existing.contentType(),
                    existing.width(), existing.height(), existing.content(), existing.thumbnail());
        }

        byte[] content;
        try {
            content = Base64.getDecoder().decode(stripDataUriPrefix(contentBase64));
        } catch (IllegalArgumentException exception) {
            throw invalidImage("Image content is not valid Base64.");
        }
        if (content.length == 0 || content.length > MAX_IMAGE_BYTES) {
            throw invalidImage("Compressed image must not exceed 1.5 MB.");
        }
        if (!isJpeg(content)) {
            throw invalidImage("Archive images must be JPEG files.");
        }

        ImageDimensions dimensions = readDimensions(content);
        if (Math.max(dimensions.width(), dimensions.height()) > MAX_IMAGE_EDGE) {
            throw invalidImage("Image longest edge must not exceed 1600 pixels.");
        }

        BufferedImage decoded;
        try {
            decoded = ImageIO.read(new ByteArrayInputStream(content));
        } catch (Exception exception) {
            throw invalidImage("Image content cannot be decoded.");
        }
        if (decoded == null || decoded.getWidth() <= 0 || decoded.getHeight() <= 0) {
            throw invalidImage("Image content cannot be decoded.");
        }
        if (decoded.getWidth() != dimensions.width() || decoded.getHeight() != dimensions.height()) {
            throw invalidImage("Image dimensions are inconsistent.");
        }

        byte[] normalizedContent = encodeJpeg(toRgb(decoded), 0.82f);
        if (normalizedContent.length > MAX_IMAGE_BYTES) {
            throw invalidImage("Compressed image must not exceed 1.5 MB.");
        }
        BufferedImage thumbnail = scaleWithin(decoded, THUMBNAIL_EDGE);
        return new ArchiveImage(
                newImageId(),
                deviceId,
                sortOrder,
                "image/jpeg",
                decoded.getWidth(),
                decoded.getHeight(),
                normalizedContent,
                encodeJpeg(toRgb(thumbnail), 0.82f));
    }

    private ArchiveImage copyForArchive(ArchiveImage image, String deviceId, int sortOrder) {
        return new ArchiveImage(
                image.id(), deviceId, sortOrder, image.contentType(), image.width(), image.height(),
                image.content(), image.thumbnail());
    }

    private BufferedImage scaleWithin(BufferedImage source, int maximumEdge) {
        double scale = Math.min(1.0, (double) maximumEdge / Math.max(source.getWidth(), source.getHeight()));
        int width = Math.max(1, (int) Math.round(source.getWidth() * scale));
        int height = Math.max(1, (int) Math.round(source.getHeight() * scale));
        BufferedImage result = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = result.createGraphics();
        graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        graphics.drawImage(source, 0, 0, width, height, null);
        graphics.dispose();
        return result;
    }

    private BufferedImage toRgb(BufferedImage source) {
        if (source.getType() == BufferedImage.TYPE_INT_RGB) {
            return source;
        }
        BufferedImage rgb = new BufferedImage(source.getWidth(), source.getHeight(), BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = rgb.createGraphics();
        graphics.drawImage(source, 0, 0, null);
        graphics.dispose();
        return rgb;
    }

    private byte[] encodeJpeg(BufferedImage image, float quality) {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        try (ByteArrayOutputStream output = new ByteArrayOutputStream();
                ImageOutputStream imageOutput = ImageIO.createImageOutputStream(output)) {
            writer.setOutput(imageOutput);
            ImageWriteParam parameters = writer.getDefaultWriteParam();
            parameters.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            parameters.setCompressionQuality(quality);
            writer.write(null, new IIOImage(image, null, null), parameters);
            return output.toByteArray();
        } catch (Exception exception) {
            throw invalidImage("Image could not be encoded.");
        } finally {
            writer.dispose();
        }
    }

    private String stripDataUriPrefix(String value) {
        int separator = value.indexOf(',');
        return value.startsWith("data:") && separator >= 0 ? value.substring(separator + 1) : value;
    }

    private boolean isJpeg(byte[] content) {
        return content.length >= 3
                && (content[0] & 0xff) == 0xff
                && (content[1] & 0xff) == 0xd8
                && (content[2] & 0xff) == 0xff;
    }

    private ImageDimensions readDimensions(byte[] content) {
        ImageReader reader = null;
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(content))) {
            Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) {
                throw invalidImage("Image content cannot be decoded.");
            }
            reader = readers.next();
            reader.setInput(input, true, true);
            int width = reader.getWidth(0);
            int height = reader.getHeight(0);
            if (width <= 0 || height <= 0) {
                throw invalidImage("Image dimensions are invalid.");
            }
            return new ImageDimensions(width, height);
        } catch (BusinessException exception) {
            throw exception;
        } catch (Exception exception) {
            throw invalidImage("Image metadata cannot be read.");
        } finally {
            if (reader != null) {
                reader.dispose();
            }
        }
    }

    private String normalize(String value) {
        return value == null ? "" : value.trim();
    }

    private String newImageId() {
        return "archive-image-" + UUID.randomUUID();
    }

    private BusinessException invalidImage(String message) {
        return new BusinessException(ErrorCode.ARCHIVE_REQUEST_INVALID, message);
    }

    private record ImageDimensions(int width, int height) {
    }
}
