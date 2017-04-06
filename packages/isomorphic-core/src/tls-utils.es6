import constants from 'constants';

const INSECURE_TLS_OPTIONS = {
  secureProtocol: 'SSLv23_method',
  rejectUnauthorized: false,
}

const SECURE_TLS_OPTIONS = {
  secureProtocol: 'SSLv23_method',
  // See similar code in cloud-core for explanation of each flag:
  // https://github.com/nylas/cloud-core/blob/e70f9e023b880090564b62fca8532f56ec77bfc3/sync-engine/inbox/auth/generic.py#L397-L435
  secureOptions: constants.SSL_OP_NO_SSLv3 | constants.SSL_OP_NO_SSLv2 | constants.SSL_OP_NO_COMPRESSION | constants.SSL_OP_CIPHER_SERVER_PREFERENCE | constants.SSL_OP_SINGLE_DH_USE | constants.SSL_OP_SINGLE_ECDH_USE,
}

export {SECURE_TLS_OPTIONS, INSECURE_TLS_OPTIONS};
