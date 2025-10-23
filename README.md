# About Triton

Triton is a dotfile management tool made for use in combination with GNU Stow. It was made to address:
  1) User interest in easily switching between GROUPS of configuration files accomplishing the same tasks (EG, alternate ricing setups)

# Triton Themes

Triton's themetool is the primary purpose for which the dotfile manager was created to begin with. If you like the freedom of switching between themes at will, you may be interested in using this tool often.
When setting a new theme from the .themes directory (usually located at $HOME/<username>/dotfiles/.triton/.themes), triton copies the theme in its entirety to the .../dotfiles/.triton/ directory as "current_theme"/. Any existing current_theme/ directory is first deleted.

This keeps users from changing theme defaults under .themes/ that could then be overwritten by upstream updates. If users wish to truly change any theme settings, they must _deliberately_ go to the theme directory, make their modifications, and then reset their current_theme with the added changes. It is recommended that a backup is saved before such changes to a theme.

