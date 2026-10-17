The pre-minigame screen that should appear before every minigame. The same scene should be used every time. Components of the scene will change according to the selected minigame. Here the player's will be able to visualize a preview of the minigame and instructions on how to play it. Furthermore every player will need to press the "READY" button on their phone, the minigame only starts after all the players are ready. 

The screen will be divided in 3 logical sections: Minigame preview tablet, Instruction booklet, Players tray.

### Minigame Preview
This section occupies the biggest part of the screen. A 16:9 screenshot of the minigame is displayed in a Tablet that sits on top of the table. In a future version of the game a video of the minigame will be displayed, but for now it's just one screenshot. The minigame name appears on the top of it, we can use a floating label for now.

### Instructions booklet
To the right of the Minigame Preview there's a booklet and the instruction of the minigame are written on top of the page, as if they were printed there. The instructions for now will be only text based. In the future we can add some illustrations to exemplify the inputs. Instructions should be direct and concise but also lighthearted and funny. Controls, win condition and "hints" are the parts of the elements of a minigame instructions page.

### Players tray
Each player's character in the lobby will appear here in order. When they press "READY" on their phone a green label will appear on top of their head with the text "Ready!".

#### Notes
In this screen players can only press READY or CANCEL to toggle on/off their ready status. Characters movement won't be available here.

### Ready flow and phone presentation

- The host uses the lobby's existing **Start** action to open this screen. The host can cancel back to the lobby. The game starts automatically when every registered phone player in the selected round is ready; the host computer is not a participant.
- The one-player F12 debug launch bypasses this screen.
- A phone that already had onboarding open before the host presses **Start** may finish joining while this screen is open. The new player is added to the selected round as unready. The screen has no join QR; onboarding that was not already open cannot begin during this phase. The join window closes when the all-ready transition starts the minigame.
- A player who disconnects while waiting remains in the round. Reconnecting restores the pre-minigame screen in an unready state, and that player must press **READY** again.
- On the phone, show only one large **READY / CANCEL** toggle and its current ready state. Keep the preview and instructions on the shared display.
- Tilt Shift also exposes motion permission and neutral calibration. Explain landscape
  holding and unlocking rotation if needed; READY is blocked in portrait and cleared when
  landscape eligibility is lost while waiting. Round readiness inside gameplay does not
  replace this screen.
