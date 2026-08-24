# ICON information

This project uses lucid icons right from the github project. As cloning the complete lucid icon set into this project would to much I decided that the repo will not include all icons which where used. 

Instead if you want to use them your self please execute one of the following ways or dig into the project and replace the icons with your own on your personal instance.

## Option 1: svn

1. Go into the quickshell project root
2. Use the following Command:

```bash
svn export https://github.com/lucide-icons/lucide/trunk/icons icons
```

## Option 2: git

1. Go into the quickshell project root
2. Use the following Command:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/lucide-icons/lucide.git tmp-lucide
cd tmp-lucide
git sparse-checkout set icons
mv icons ../icons
cd .. && rm -rf tmp-lucide
```