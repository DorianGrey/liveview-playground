import { arrayBufferToBase64, arrayBufferToString, base64ToArrayBuffer } from "./utils";

const WebAuthnRegistrationHook = {
  mounted() {
    this.handleEvent("webauthn:start-registration", async (data) => {
      console.info("webauthn:start-registration -> init", data);
      try {
        // TODO: Check if this is technically correct
        const parsedChallenge = base64ToArrayBuffer(data.challenge);
        const userId = base64ToArrayBuffer(data.user_id);

        const config = {
          publicKey: {
            challenge: parsedChallenge,
            // TODO: ?
            rp: {
              id: data.rp_id,
              name: location.hostname,
            },
            user: {
              id: userId,
              name: data.user,
              displayName: data.user,
            },
            attestation: data.attestation,
            authenticatorSelection: {
              residentKey: "preferred",
              userVerification: "preferred",
            },
            // See recommendations:
            // https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredentialCreationOptions#alg
            pubKeyCredParams: [
              { type: "public-key", alg: -7 }, // ES256 (ECDSA)
              { type: "public-key", alg: -8 }, // Ed25519
              { type: "public-key", alg: -35 }, // ES384 (ECDSA)
              { type: "public-key", alg: -36 }, // ES512 (ECDSA)
              { type: "public-key", alg: -257 }, // RS256 (RSA)
              { type: "public-key", alg: -258 }, // RS384 (RSA)
              { type: "public-key", alg: -259 }, // RS512 (RSA)
              { type: "public-key", alg: -38 }, // PS256 (RSA-PSS)
              { type: "public-key", alg: -39 }, // PS384 (RSA-PSS)
              { type: "public-key", alg: -40 }, // PS512 (RSA-PSS)
            ],
            timeout: data.timeout,
          },
        };

        const assertion = await navigator.credentials.create(config);
        if (assertion != null) {
          // Contains a https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential
          console.info("webauthn:start-registration -> responding", assertion);

          this.pushEvent("finish_registration", {
            response: {
              id: assertion.id,
              rawId: arrayBufferToBase64(assertion.rawId),
              clientDataJSON: arrayBufferToString(
                assertion.response.clientDataJSON
              ),
              attestationObject: arrayBufferToBase64(
                assertion.response.attestationObject
              ),
              type: assertion.type,
            },
          });
        } else {
          console.error("No assertion created");
        }
      } catch (err) {
        console.error("webauthn:start-registration -> failed", err);
      }
    });
  },
};

export default { WebAuthnRegistrationHook };
