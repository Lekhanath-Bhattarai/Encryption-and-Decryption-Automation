#!/bin/bash

# Ensure directories exist on both systems
echo "Creating directories on both systems..."
ssh lekhanath@192.168.10.68 'mkdir -p /home/lekhanath/folder2'
mkdir -p /home/kali/folder1

# Generate asymmetric keys on System 1
echo "Generating RSA keys on System 1..."
openssl genpkey -algorithm RSA -out /home/kali/folder1/kali_key_pvy.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in /home/kali/folder1/kali_key_pvy.pem -out /home/kali/folder1/kali_key_pub.pem

# Generate asymmetric keys on System 2
echo "Generating RSA keys on System 2..."
ssh lekhanath@192.168.10.68 'openssl genpkey -algorithm RSA -out /home/lekhanath/folder1/lekhanath_key_pvt.pem -pkeyopt rsa_keygen_bits:2048'
ssh lekhanath@192.168.10.68 'openssl rsa -pubout -in /home/lekhanath/folder1/lekhanath_key_pvt.pem -out /home/lekhanath/folder1/lekh_key_pub.pem'

# Generate symmetric key and data on System 1
echo "Generating symmetric key and data on System 1..."
openssl rand -base64 32 > /home/kali/folder1/symmetric_key
echo 'This is some data to encrypt' > /home/kali/folder1/data.txt

# Encrypt the data using the symmetric key
echo "Encrypting the data on System 1..."
openssl enc -aes-256-cbc -salt -in /home/kali/folder1/data.txt -out /home/kali/folder1/data.enc -pass file:/home/kali/folder1/symmetric_key

# Encrypt the symmetric key using System 2's public key
echo "Encrypting the symmetric key on System 1..."
openssl rsautl -encrypt -inkey /home/kali/folder1/lekh_key_pub.pem -pubin -in /home/kali/folder1/symmetric_key -out /home/kali/folder1/symmetric_key.enc

# Copy encrypted files and public keys between systems
echo "Copying encrypted files and keys between systems..."
scp /home/kali/folder1/data.enc /home/kali/folder1/symmetric_key.enc lekhanath@192.168.10.68:/home/lekhanath/folder2/
scp /home/kali/folder1/kali_key_pub.pem lekhanath@192.168.10.68:/home/lekhanath/folder2/
scp lekhanath@192.168.10.68:/home/lekhanath/folder1/lekh_key_pub.pem /home/kali/folder1/

# Create generate_and_sign.sh script on System 1
echo "Creating generate_and_sign.sh script on System 1..."
cat <<'EOF' > /home/kali/folder1/generate_and_sign.sh
#!/bin/bash
echo "Generated file at $(date)" > /home/kali/folder1/generated_file.txt
openssl dgst -sha256 -sign /home/kali/folder1/kali_key_pvy.pem -out /home/kali/folder1/signature.bin /home/kali/folder1/generated_file.txt
scp /home/kali/folder1/generated_file.txt lekhanath@192.168.10.68:/home/lekhanath/folder2/
scp /home/kali/folder1/signature.bin lekhanath@192.168.10.68:/home/lekhanath/folder2/
ssh lekhanath@192.168.10.68 "openssl dgst -sha256 -verify /home/lekhanath/folder2/lekh_key_pub.pem -signature /home/lekhanath/folder2/signature.bin /home/lekhanath/folder2/generated_file.txt && echo 'Verification successful'"
EOF

# Make the script executable
chmod +x /home/kali/folder1/generate_and_sign.sh

# Create crontab entry on System 1
echo "Creating crontab entry on System 1..."
(crontab -l 2>/dev/null; echo '30 16 * * * /home/kali/folder1/generate_and_sign.sh') | crontab -

# Decrypt the symmetric key on System 2
echo "Decrypting the symmetric key on System 2..."
ssh lekhanath@192.168.10.68 'openssl rsautl -decrypt -inkey /home/lekhanath/folder1/lekhanath_key_pvt.pem -in /home/lekhanath/folder2/symmetric_key.enc -out /home/lekhanath/folder2/symmetric_key'

# Decrypt the data using the decrypted symmetric key on System 2
echo "Decrypting the data on System 2..."
ssh lekhanath@192.168.10.68 'openssl enc -aes-256-cbc -d -in /home/lekhanath/folder2/data.enc -out /home/lekhanath/folder2/decrypted_data.txt -pass file:/home/lekhanath/folder2/symmetric_key'

echo "Automation script completed successfully."
