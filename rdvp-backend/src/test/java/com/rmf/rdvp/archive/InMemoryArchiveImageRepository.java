package com.rmf.rdvp.archive;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import javax.imageio.ImageIO;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;

@Repository
@Profile("test")
public class InMemoryArchiveImageRepository implements ArchiveImageRepository {

    private final Map<String, ArchiveImage> imagesById = new ConcurrentHashMap<>();
    private final InMemoryArchiveRepository archiveRepository;

    public InMemoryArchiveImageRepository(InMemoryArchiveRepository archiveRepository) {
        this.archiveRepository = archiveRepository;
        addPlaceholder("device-local-0001", "archive-image-local-0001");
        addPlaceholder("device-local-0002", "archive-image-local-0002");
        addPlaceholder("device-local-0003", "archive-image-local-0003");
    }

    @Override
    public List<ArchiveImage> findByDeviceId(String deviceId) {
        return imagesById.values().stream()
                .filter(image -> image.deviceId().equals(deviceId))
                .sorted(Comparator.comparingInt(ArchiveImage::sortOrder))
                .toList();
    }

    @Override
    public Optional<ArchiveImage> findById(String imageId) {
        ArchiveImage image = imagesById.get(imageId);
        if (image == null || archiveRepository.findById(image.deviceId()).isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(image);
    }

    @Override
    public void replaceForDevice(String deviceId, List<ArchiveImage> images, String operatorId) {
        new ArrayList<>(imagesById.values()).stream()
                .filter(image -> image.deviceId().equals(deviceId))
                .forEach(image -> imagesById.remove(image.id()));
        images.forEach(image -> imagesById.put(image.id(), image));
    }

    private void addPlaceholder(String deviceId, String imageId) {
        byte[] content = placeholderJpeg();
        imagesById.put(imageId, new ArchiveImage(
                imageId, deviceId, 0, "image/jpeg", 320, 200, content, content));
    }

    private byte[] placeholderJpeg() {
        try {
            BufferedImage image = new BufferedImage(320, 200, BufferedImage.TYPE_INT_RGB);
            Graphics2D graphics = image.createGraphics();
            graphics.setColor(new Color(238, 242, 245));
            graphics.fillRect(0, 0, 320, 200);
            graphics.setColor(new Color(75, 92, 108));
            graphics.fillRoundRect(102, 58, 116, 84, 12, 12);
            graphics.setColor(new Color(238, 242, 245));
            graphics.fillOval(145, 83, 30, 30);
            graphics.dispose();
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            ImageIO.write(image, "jpeg", output);
            return output.toByteArray();
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to create archive image fixture.", exception);
        }
    }
}
