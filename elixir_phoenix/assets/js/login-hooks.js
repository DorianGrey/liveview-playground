import {
  arrayBufferToBase64,
  arrayBufferToString,
  base64ToArrayBuffer,
} from "./utils";

const LoginHook = {
  mounted() {
    this.handleEvent(
      "webauthn:start-login",
      async ({ challenge, rp_id, timeout }) => {
        try {
          // TODO: Check if this is technically correct
          const parsedChallenge = base64ToArrayBuffer(challenge);
          const assertion = await navigator.credentials.get({
            publicKey: {
              challenge: parsedChallenge,
              rpId: rp_id,
              timeout,
              // TODO: allowCredentials ?
            },
          });

          // Contains a https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential
          if (assertion != null) {
            this.pushEvent("finish_login", {
              response: {
                rawId: arrayBufferToBase64(assertion.rawId),
                type: assertion.type,
                clientDataJSON: arrayBufferToString(
                  assertion.response.clientDataJSON
                ),
                authenticatorData: arrayBufferToBase64(
                  assertion.response.authenticatorData
                ),
                sig: arrayBufferToBase64(assertion.response.signature),
                userHandle: arrayBufferToBase64(assertion.response.userHandle),
              },
            });
          } else {
            console.error("No assertion created");
          }
        } catch (err) {
          console.error(err);
        }
      }
    );
  },
};

export default { LoginHook };
