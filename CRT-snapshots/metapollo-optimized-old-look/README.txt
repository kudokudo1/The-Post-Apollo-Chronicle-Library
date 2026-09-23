Metapollo optimized control / old-look test build

Replaces only:
  ~/.config/kitty/shaders/metapollo-crt.pipeline
  ~/.config/kitty/shaders/metapollo-signal.slang
  ~/.config/kitty/shaders/metapollo-signal-state.slang
  ~/.config/kitty/shaders/metapollo-signal-copy.slang

The old source files remain untouched on disk.

Current TEST timing:
  0-3 sec  active
  3-5 sec  pre-sleep state (visuals intentionally unchanged)
  5 sec    old purple static + big wobble transition
  then     old NO SIGNAL appearance
  activity old purple static + big wobble transition
  then     active

Install after downloading this archive:
  cp ~/.config/kitty/shaders/metapollo-crt.pipeline ~/.config/kitty/shaders/metapollo-crt.pipeline.pre-opt-backup
  tar -xzf ~/Downloads/metapollo-optimized-old-look.tar.gz -C ~

Launch:
  ~/.local/kitty-nightly/kitty.app/bin/kitty \
      --debug-rendering \
      --config ~/.config/kitty/kitty.conf \
      -o 'shell /bin/zsh' \
      -o 'custom_shaders metapollo-crt'
