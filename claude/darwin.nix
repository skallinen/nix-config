# Claude Code's global instructions on the Mac (Sami, 2026-09-30, utm-arch D26):
# ~/.claude/CLAUDE.md becomes a link to ./CLAUDE.md in this repo, so the bootstrap
# recreates it. The link goes out of the store (mkOutOfStoreSymlink), so editing
# ~/.claude/CLAUDE.md edits this repo's file, not a read-only store copy.
#
# Imported for the Air only (flake.nix), next to the macbridge: the file names the
# utm-arch VM, which runs on the Air. The Pro keeps its own hand-kept file until
# Sami decides otherwise.
#
# The VM has its own, different file, written by utm-home.nix
# (home.file.".claude/CLAUDE.md".text). Not merged with this one.
#
# First switch: Home Manager finds the existing ~/.claude/CLAUDE.md and moves it to
# ~/.claude/CLAUDE.md.backup (home-manager.backupFileExtension = "backup" in
# darwin-configuration.nix), then links it here. It refuses if that .backup file
# already exists.
{ ... }:

{
  home-manager.users.samikallinen = { config, ... }: {
    home.file.".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/claude/CLAUDE.md";
  };
}
