extends TestScript


func _run() -> void:
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var other_key := crypto.generate_rsa(2048)
	var valid := crypto.generate_self_signed_certificate(
		key,
		"CN=localhost,O=Play Shapes Test",
		"20260101000000",
		"20300101000000",
	)
	var expired := crypto.generate_self_signed_certificate(
		key,
		"CN=localhost",
		"20200101000000",
		"20210101000000",
	)
	var directory := "res://test-results/tls"
	DirAccess.make_dir_recursive_absolute(directory)
	check(
		valid.save(directory.path_join("certificate.pem")) == OK,
		"The valid certificate is written to disk",
	)
	check(
		expired.save(directory.path_join("expired.pem")) == OK,
		"The expired certificate is written to disk",
	)
	check(key.save(directory.path_join("key.pem")) == OK, "The private key is written to disk")
	var valid_pem := FileAccess.get_file_as_string(directory.path_join("certificate.pem"))
	check(
		ControllerCertificate.inspect(valid_pem, key).is_empty(),
		"A certificate and its own key are accepted",
	)
	check(
		ControllerCertificate.inspect(valid_pem, other_key).contains("do not match"),
		"A certificate with another key is reported as not matching",
	)
	var expired_pem := FileAccess.get_file_as_string(directory.path_join("expired.pem"))
	check(
		ControllerCertificate.inspect(expired_pem, key).contains("expired"),
		"An expired certificate is reported as expired",
	)
	var config := ControllerNetworkConfig.new()
	config.tls_enabled = true
	var tls := ControllerTLS.new()
	check(tls.prepare(config) != OK, "TLS without a certificate and key cannot be prepared")
	config.certificate_path = directory.path_join("certificate.pem")
	config.private_key_path = directory.path_join("key.pem")
	check(tls.prepare(config) == OK, "TLS with a matching certificate and key is prepared")
	var fixture := FileAccess.open(directory.path_join("network.json"), FileAccess.WRITE)
	fixture.store_string(
		JSON.stringify(
			{
				"tls_enabled": true,
				"certificate_path": "certificate.pem",
				"private_key_path": "key.pem",
				"http_port": 18443,
				"websocket_port": 18444,
			}
		)
	)
	fixture.close()
