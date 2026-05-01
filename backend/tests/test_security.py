from app.core.security import hash_password, verify_password, create_access_token, encrypt_api_key, decrypt_api_key

def test_hash_and_verify_password():
    hashed = hash_password("mypassword")
    assert verify_password("mypassword", hashed) is True
    assert verify_password("wrongpassword", hashed) is False

def test_create_access_token():
    token = create_access_token(data={"sub": "testuser"})
    assert isinstance(token, str)
    assert len(token) > 0

def test_encrypt_decrypt_api_key():
    original = "sk-test-key-12345"
    encrypted = encrypt_api_key(original)
    assert encrypted != original
    decrypted = decrypt_api_key(encrypted)
    assert decrypted == original
