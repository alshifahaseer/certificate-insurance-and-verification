document.getElementById("verificationForm").addEventListener("submit", function(event) {
    event.preventDefault();

    const certId = document.getElementById("certificateId").value.trim();
    const resultDiv = document.getElementById("result");
    const statusText = document.getElementById("verificationStatus");

    // Simulated verification logic
    if (certId === "") {
        statusText.innerText = "Please enter a certificate ID.";
        resultDiv.classList.remove("hidden");
        return;
    }

    // Fake verification check
    const validIds = ["CERT123", "INSURE456", "VERIFIED789"];

    if (validIds.includes(certId.toUpperCase())) {
        statusText.innerText = `✅ Certificate ID "${certId}" is verified and insured.`;
    } else {
        statusText.innerText = `❌ Certificate ID "${certId}" is not found or invalid.`;
    }

    resultDiv.classList.remove("hidden");
});
