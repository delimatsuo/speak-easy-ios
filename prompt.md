The specs are located in /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/Specs.
The main code will be developed in /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/Source.

Create:
- A Project Manager agent. (Already running; orchestrator should recognize and utilize it, or recreate if needed)
- A Frontend Development Team, consisting of:
    - A Frontend Project Manager (FrontendPM) to oversee UI development.
    - A Frontend Developer (FrontendDev) to write Swift/SwiftUI code for the iPhone UI.
    - A Frontend UI Tester (FrontendTester) to ensure UI responsiveness and correctness.
- A Backend/Core Logic Team, consisting of:
    - A Backend Project Manager (BackendPM) to oversee core logic development.
    - A Backend Developer (BackendDev) to implement STT, Gemini API integration, and audio playback.
    - A Backend Tester (BackendTester) to write and run integration tests for the core logic.

Schedule:
- 15-minute check-ins for all Project Managers.
- 30-minute code commits from developers.
- 1-hour orchestrator status sync.

Goals for initial development phase:
- Frontend Team: Implement the core UI for the two-way voice translation loop as described in frontend_spec.md.
- Backend/Core Logic Team: Implement on-device STT and the full Gemini 2.5 Pro API integration for translation and TTS, as described in backend_spec.md.The specs are located in /Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/Specs.

Create:
- A Project Manager agent. This agent's primary task is to create the initial project specification documents.

Schedule:
- The Project Manager agent should immediately start creating 'main_spec.md' based on the project requirements.
- Schedule a check-in for the orchestrator to confirm 'main_spec.md' creation.
