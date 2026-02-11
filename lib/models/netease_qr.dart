// Login state enum
enum QRLoginState { waiting, scanned, success, expired, error }

class QRLoginStatus {
  final QRLoginState state;
  final String? message;
  final String? nickname;
  final String? avatar;
  final String? cookie;
  final String? accountId;

  QRLoginStatus._({
    required this.state,
    this.message,
    this.nickname,
    this.avatar,
    this.cookie,
    this.accountId,
  });

  factory QRLoginStatus.waiting() =>
      QRLoginStatus._(state: QRLoginState.waiting);

  factory QRLoginStatus.scanned({String? nickname, String? avatar}) =>
      QRLoginStatus._(
        state: QRLoginState.scanned,
        nickname: nickname,
        avatar: avatar,
      );

  factory QRLoginStatus.success({required String cookie, String? accountId}) =>
      QRLoginStatus._(
        state: QRLoginState.success,
        cookie: cookie,
        accountId: accountId,
      );

  factory QRLoginStatus.expired({String? message}) => QRLoginStatus._(
    state: QRLoginState.expired,
    message: message ?? '二维码已过期',
  );

  factory QRLoginStatus.error(String message) =>
      QRLoginStatus._(state: QRLoginState.error, message: message);
}

class QRLoginResult {
  final String key;
  final String? qrImage;

  QRLoginResult({required this.key, this.qrImage});
}
