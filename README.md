# ulcplayer-nds
Nintendo DS player for [ulc-codec](https://github.com/Aikku93/ulc-codec).

![Screenshot](/Screenshot.png?raw=true)

## Details

As a proof of concept of the decoding complexity of ulc-codec, a Nintendo DS demonstration was made. CPU usage is around 35% (ARM7) for 32728Hz @ 128kbps (M/S stereo). Note that this is entirely a proof of concept; decode time for BlockSize=2048 (default for encoding tool) is 1-2 frames, so usage in real applications would need some form of threading to avoid excessive lag. On top of that, streaming audio requires data to be read from card periodically, potentially causing underrun issues; underrun is generally unrecoverable and tends to crash the player.

To use this player, you must:
 * Have devKitPro installed and ready to build NDS programs (if compiling from source)
 * For streamed audio (no recompilation necessary):
   * Use an interface that supports DLDI (eg. DeSmuME or hardware)
   * Add your tracks into a folder named "ulc" (see demo file)
   * If desired, metadata (track name, artist name, and cover art) may be added via the AddMetadata.py script
 * For pre-compiled audio:
   * Add tracks in arm9/source/TrackListings.s

By default, the player uses a quadrature oscillator for [IM]DCT routines, and supports both mono and stereo files and any block size up to 2048.

## Authors
 * **Ruben Nunez** - *Initial work* - [Aikku93](https://github.com/Aikku93)

## Acknowledgements
* Credit goes to the following artists for their tracks used as demos:
  * [Crypton](https://music.youtube.com/channel/UCvqH0bSFhwjzzW_fp2oVdXA)
  * [Dr. Rude](https://music.youtube.com/channel/UCdWjqbcoRdjQlua6e2OQdZg)
  * [RATKID](https://www.facebook.com/ratkidmusic/)
  * [Sefa](https://djsefa.com/)

## Pre-built Demo (Last update: 2022/09/18)

Files:
 * [2022.09.18 release (1.5MiB, 7z compressed)](https://www.mediafire.com/file/7q49nx9o4oiooia/file)

Featuring:
 * Sefa & Crypton - Lastig (as pre-compiled track)
 * Dr. Rude & RATKID - Self Esteem (as streamed audio)
