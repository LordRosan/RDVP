import { CurrentUserSnapshot } from '../models/SessionModels';

export class SessionStore {
  static getCurrentUser(): CurrentUserSnapshot {
    return {
      displayName: '未登录用户',
      roleName: '权限未加载',
      online: false
    };
  }
}

