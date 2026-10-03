class_name ControllerTLS
extends RefCounted
## Load once before either listener starts; private material stays host-local.

var options: TLSOptions
var error := ""


func prepare(config: ControllerNetworkConfig) -> Error:
	options = null
	error = ""
	if not config.tls_enabled:
		return OK
	for path: String in [config.certificate_path, config.private_key_path]:
		if path.is_empty() or not FileAccess.file_exists(path):
			error = (
				"HTTPS requires readable certificate_path and private_key_path files. "
				+ "Run the local HTTPS setup."
			)
			return ERR_FILE_NOT_FOUND
	var certificate := X509Certificate.new()
	var key := CryptoKey.new()
	if certificate.load(config.certificate_path) != OK or key.load(config.private_key_path) != OK:
		error = "HTTPS certificate or private key is invalid; use matching PEM files."
		return ERR_FILE_CORRUPT
	error = ControllerCertificate.inspect(
		FileAccess.get_file_as_string(config.certificate_path),
		key,
	)
	if not error.is_empty():
		return ERR_FILE_CORRUPT
	options = TLSOptions.server(key, certificate)
	return OK
