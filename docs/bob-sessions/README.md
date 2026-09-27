# IBM Bob task sessions and screenshots

Evidence of how the team used IBM Bob for the IBM Bob 2.0 Hackathon: Bobalytics session summaries
and screenshots of Alice while Bob was working through the Companion agent.

Development was a mix of tools. We used the Bob IDE to test, develop further and let the product
improve itself (steering Bob from Alice while Bob improved Alice), and the Bob CLI (Bob Shell) for
automated end-to-end tests, alongside other coding tools.

## Franz Anhäupl: Bobalytics session summary

Last 30 days, user scope, as of 27 September 2026.

| | |
| --- | --- |
| **Insights:** 15 tasks, 12 of them on 27 September. Modes used: **Agent 54 %, Companion 46 %**. Almost half of the Bob work ran through our own Companion agent. | ![Bobalytics insights](Bildschirmfoto%202026-09-27%20um%2017.18.33.png) |
| **Metrics:** Bob factor 14 % (1,364 of 9,797 lines of code), 21.51 Bobcoins spent | ![Bobalytics metrics](Bildschirmfoto%202026-09-27%20um%2017.18.23.png) |
| **Repository impact:** Bob-authored lines accepted in `Litorian113/Alice` (3 Bob commits) and the earlier `Litorian113/Bob-Companion-App` prototype (37 % of committed lines). By language: Swift 67 %, Markdown 28 %, YAML 3 % | ![Bob usage by repository](Bildschirmfoto%202026-09-27%20um%2017.18.41.png) |
| **Today:** 12 tasks completed with Bob on the final hackathon day | ![Bobalytics today](Bildschirmfoto%202026-09-27%20um%2017.18.49.png) |
| **Subscription:** team `ibm-hackathon-lablab`, 40 Bobcoin limit, 22 used | ![Bob subscription](Bildschirmfoto%202026-09-27%20um%2017.18.13.png) |

## Bob IDE sessions

| | |
| --- | --- |
| **Pairing from the Bob IDE:** "pair my phone" runs `pair_phone` from our `bob-companion` MCP server and shows the QR code in Bob's chat. | ![Bob IDE pairing](Bildschirmfoto%202026-09-27%20um%2017.23.49.png) |
| **First connection test:** Bob calls `ask_decision`, the answer is tapped on the iPhone, and Bob confirms the received choice in the chat. | ![Bob IDE ask_decision test](Bildschirmfoto%202026-09-27%20um%2017.23.37.png) |
| **Bob improving Alice in Companion mode:** Bob asks for approval to commit its own Alice feature, `feat(ios): decision feedback – Alice peeks over card after ack` (commit `e4f7388` in this repository). | ![Bob committing an Alice feature in Companion mode](Bildschirmfoto%202026-09-27%20um%2017.24.03.png) |
| **Bob's native command approval** while working on the project. | ![Bob IDE command approval](Bildschirmfoto%202026-09-27%20um%2017.22.41.png) |
| **Workspaces:** the Alice repository and the earlier Bob-Companion-App prototype, opened as trusted folders in the Bob IDE. | ![Bob IDE workspace trust](Bildschirmfoto%202026-09-27%20um%2017.23.03.png) |

## Alice while Bob works

| Choice card | Command approval | Voice follow-up |
| --- | --- | --- |
| <img src="IMG_8959.PNG" width="220" alt="Choice card: What should we build next?"> | <img src="IMG_8919.PNG" width="220" alt="Approval card: rm FAVORITE_COLORS.md"> | <img src="IMG_8960.PNG" width="220" alt="Voice review: Ready to send?"> |
| Bob asks **"What should we build next? Pick the next upgrade for our app."** Alice steering Bob while Bob improves Alice. | "Can Bob run this?" with the exact command, approve once / approve for task / reject. | A spoken instruction, transcribed and reviewed before it goes back into the same Bob conversation. |

## App screens

| Splash | Alice | Usage | Profile | App icon |
| --- | --- | --- | --- | --- |
| <img src="Splashscreen.PNG" width="160" alt="Splash screen"> | <img src="Alice-Page.PNG" width="160" alt="Alice page"> | <img src="Usage-Page.PNG" width="160" alt="Usage page"> | <img src="Settingspage.PNG" width="160" alt="Profile page"> | <img src="Alice-App-Icon.PNG" width="160" alt="Alice app icon"> |

The usage page shows prototype data (Bobcoin snapshot and illustrative token numbers); it is not
connected to live Bobalytics.

Back to the [project README](../../README.md).
