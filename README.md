# liveview-playground
Playground for various liveview implementations

# What LiveViews are

`LiveViews` refer to structure with a somewhat lightweight frontend where the backend provides the template for the web view and also executes most logic that you might implement on both ends when using an SPA, like validating a form's content. The connection between both parts is handled using a websocket, optionally with a fallback to something like long polling. Once started, all communication is handled using the websocket.

This structure comes with a couple of advantages over the widely used SPAs:
* To allow good UX, you usually implement stuff like form validation on both ends - once for immediate feedback for the user, once for the validation on submit. Doing all of this on the backend helps to get rid of this technical duplication.
* There is no need to maintain an explicit REST API outside of the ones for the LiveView paths. This makes it easier to encapsulate it.
* Using a websocket allows for easy bidirectional communication. While this is also possible via SPA, it is fully baked in here and the only technology required.

However, it also comes with downsides:
* A specific backend technology is required to not screw up runtime performance. Some backends handle websockets using native threads, which is not suitable for this kind of structure, at least if you are planning for hundreds or thousands of users. The backend need to handle those using virtual threads, actors or something similar.
* Triggering client-only functionality may become more complex.
* Server-side handling of HTML templates can feel weird.
* It cannot save you entirely from doing some frontend stuff like logic and style parts.
* LiveViews do not provide an advantage for every scenario, especially when live updates are rarely or not used, the setup is sort of an overkill. However, mixing it with static content or an SPA will make the setup even more complex

# Scenarios

To play a bit with LiveViews, I have used one scneario where it is intended to be good at and one where it is not that shiny.

## Scenario 1: Publishing updates to the client

- A sample service emits events every 60 seconds.
- The latest ten of them are stored in an in-memory database and published on a specific channel.
- The LiveView picks up that list initially and updates its local version based on the received messages. As a result, it updates the view itself.

## Scenario 2: Webauthn registration and login

- The user is able to register an login via WebAuthn (e.g. via PassKey).
- A LiveView is expected to not be optimal for such cases because it requires client-side script logic.
- The intention was to have a glimpse at how LiveViews handle such cases where client-side script logic cannot be avoided.