extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


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
	assert(valid.save(directory.path_join("certificate.pem")) == OK)
	assert(expired.save(directory.path_join("expired.pem")) == OK)
	assert(key.save(directory.path_join("key.pem")) == OK)
	var valid_pem := FileAccess.get_file_as_string(directory.path_join("certificate.pem"))
	assert(ControllerCertificate.inspect(valid_pem, key).is_empty())
	assert(ControllerCertificate.inspect(valid_pem, other_key).contains("do not match"))
	assert(ControllerCertificate.inspect(FileAccess.get_file_as_string(
			directory.path_join("expired.pem")
		), key).contains("expired"))
	var config := ControllerNetworkConfig.new()
	config.tls_enabled = true
	var tls := ControllerTLS.new()
	assert(tls.prepare(config) != OK)
	config.certificate_path = directory.path_join("certificate.pem")
	config.private_key_path = directory.path_join("key.pem")
	assert(tls.prepare(config) == OK)
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
	print("Controller TLS credential checks passed")
	quit(0)
