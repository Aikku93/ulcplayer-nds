/**************************************/
//! You know things will get interesting when you
//! need this many system/file control headers...
#include <sys/types.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
/**************************************/
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/**************************************/
#include "ulc.h"
/**************************************/

#define ULC_FILES_DIR "ulc"
#define ULC_DATA_SIG "ulcDT" //! Must be 5 bytes

/**************************************/

#define FOURCC(x) ((x[0]&0xFFu) | (x[1]&0xFFu)<<8 | (x[2]&0xFFu)<<16 | (x[3]&0xFFu)<<24)

/**************************************/

struct TrackListing_t {
	char *TrackName;             //! [00h] Title
	char *Artist;                //! [04h] Artist
	char *Filename;              //! [08h] Filename (bit31=Unplayable, bit30=Inbuilt song (ie. this is a pointer to data))
	struct CoverArt_t *CoverArt; //! [0Ch] Pointer to cover art
	uint32_t RateHz;             //! [10h] Playback rate (Hz)
	uint16_t RateKbps;           //! [14h] Playback rate (kbps)
	uint16_t nChan;              //! [16h] Number of channels
	uint32_t Duration;           //! [18h] Playback time (seconds)
	uint32_t r1;                 //! [1Ch]
};

/**************************************/

extern struct TrackListing_t TrackListings[];
extern uint16_t TrackListing_SongsOrder[];
extern uint16_t TrackListing_ArtistsOrder[];

/**************************************/

static struct TrackListing_t *gComparatorListings;

static inline const char *StripDirectories(const char *s) {
	char *m = strrchr(s, '/');
	return m ? (m+1) : s;
}

static int SongsOrder_Comparator(const void *_a, const void *_b) {
	struct TrackListing_t *a = &gComparatorListings[*(const uint16_t*)_a];
	struct TrackListing_t *b = &gComparatorListings[*(const uint16_t*)_b];
	const char *fa = a->TrackName;
	const char *fb = b->TrackName;
	if(!fa) fa = StripDirectories(a->Filename);
	if(!fb) fb = StripDirectories(b->Filename);
	return strcasecmp(fa, fb);
}

static int ArtistsOrder_Comparator(const void *_a, const void *_b) {
	struct TrackListing_t *a = &gComparatorListings[*(const uint16_t*)_a];
	struct TrackListing_t *b = &gComparatorListings[*(const uint16_t*)_b];
	const char *fa = a->Artist;
	const char *fb = b->Artist;
	if( fa &&  fb) { int Res = strcasecmp(fa, fb); return Res ? Res : SongsOrder_Comparator(_a, _b); }
	if(!fa && !fb) return SongsOrder_Comparator(_a, _b);
	if(!fa &&  fb) return +0x7FFFFFFF; //! Push all unknown artists to the bottom
	if( fa && !fb) return -0x7FFFFFFF;
	__builtin_unreachable(); //! Not sure why gcc doesn't detect this
}

static void SortTracks(uint16_t *SongsOrder, uint16_t *ArtistsOrder, struct TrackListing_t *Listings, uint32_t nListings, uint32_t StartOffs, uint32_t MaxListings) {
	uint32_t n;

	//! Pre-populate order
	for(n=StartOffs;n<nListings;n++) {
		SongsOrder[n] = ArtistsOrder[n] = n;
	}

	//! Apply first-pass sorting
	gComparatorListings = Listings;
	qsort(SongsOrder   + StartOffs, nListings-StartOffs, sizeof(uint16_t), SongsOrder_Comparator);
	qsort(ArtistsOrder + StartOffs, nListings-StartOffs, sizeof(uint16_t), ArtistsOrder_Comparator);
}

static void PopulateListing(struct TrackListing_t *Listing, int Fd, struct ulc_FileHeader_t *Header, uint32_t FilenameStringPtrOffset) {
	Listing->TrackName  = NULL;
	Listing->Artist     = NULL;
	Listing->Filename   = (void*)FilenameStringPtrOffset;
	Listing->CoverArt   = NULL;
	Listing->RateHz     = Header->RateHz;
	Listing->nChan      = Header->nChan;
	Listing->Duration   = Header->nBlocks * Header->BlockSize / Header->RateHz;
	Listing->RateKbps   = lseek(Fd, 0, SEEK_END)*8ull * Header->RateHz / 1000 / (Header->nBlocks * Header->BlockSize);
}

uint32_t TrackListing_Populate(uint32_t nInbuiltTracks, uint32_t MaxListings) {
	if(nInbuiltTracks > MaxListings) nInbuiltTracks = MaxListings;
	uint32_t nAllocTracks = nInbuiltTracks;

	//! Sort the inbuilt tracks separately
	SortTracks(TrackListing_SongsOrder, TrackListing_ArtistsOrder, TrackListings, nAllocTracks, 0, MaxListings);

	//! Scan for files
	DIR *Dir = opendir(ULC_FILES_DIR);
	if(Dir) {
		//! Parse all files
		struct dirent *DirEnt;
		char *DataBuffer = NULL;
		uint32_t DataBufferOffs = 0;
		while(nAllocTracks < MaxListings && (DirEnt = readdir(Dir))) {
			//! Make sure this isn't . or ..
			if(!strcmp(DirEnt->d_name, ".") || !strcmp(DirEnt->d_name, "..")) continue;

			//! Allocate space for this filename and store it
			uint32_t FilenameStringSize = strlen(ULC_FILES_DIR) + 1 + strlen(DirEnt->d_name) + 1; //! Add '/' and NUL terminator
			FilenameStringSize = (FilenameStringSize+3) &~ 3; //! <- Keep everything 4-byte aligned
			{
				char *NewDataBuffer = realloc(DataBuffer, DataBufferOffs + FilenameStringSize);
				if(!NewDataBuffer) continue;
				DataBuffer = NewDataBuffer;
			}
			char *FilenameStringPtr = DataBuffer+DataBufferOffs;
			siprintf(FilenameStringPtr, ULC_FILES_DIR "/%s", DirEnt->d_name);

			//! Try to open the file
			int Fd = open(FilenameStringPtr, O_RDONLY);
			if(Fd != -1) {
				//! Read ULC header and verify file
				struct ulc_FileHeader_t Header;
				read(Fd, &Header, sizeof(struct ulc_FileHeader_t));
				if(Header.Magic == FOURCC("ULC2")) {
					struct TrackListing_t *Listing = &TrackListings[nAllocTracks];

					//! We have a file - keep this pointer and populate listing
					PopulateListing(Listing, Fd, &Header, DataBufferOffs);
					DataBufferOffs += FilenameStringSize;
					nAllocTracks++;

					//! Parse additional data
					off_t CurOffs = lseek(Fd, 0, SEEK_END);
					for(;;) {
						//! Check for signature
						struct {
							char     Sig[5];
							uint8_t  Type;
							uint16_t Size;
						} Data;
						lseek(Fd, CurOffs -= sizeof(Data), SEEK_SET);
						read(Fd, &Data, sizeof(Data));
						if(memcmp(Data.Sig, ULC_DATA_SIG, sizeof(Data.Sig))) break;

						//! Try to match data
						void **DataPtrDst = NULL;
						switch(Data.Type) {
							//! 00h = TrackName
							case 0x00: {
								DataPtrDst = (void**)&Listing->TrackName;
							} break;

							//! 01h = Artist
							case 0x01: {
								DataPtrDst = (void**)&Listing->Artist;
							} break;

							//! 02h = CoverArt
							case 0x02: {
								DataPtrDst = (void**)&Listing->CoverArt;
							} break;
						}
						if(!DataPtrDst) break;

						//! Seek to beginning of data and read
						lseek(Fd, CurOffs -= Data.Size, SEEK_SET);
						char *NewBuf = realloc(DataBuffer, DataBufferOffs + Data.Size);
						if(NewBuf) {
							//! Read data
							DataBuffer = NewBuf;
							*DataPtrDst = (void*)DataBufferOffs;
							read(Fd, DataBuffer + DataBufferOffs, Data.Size);
							DataBufferOffs += Data.Size;
						}
					}
				}

				//! Close handle
				close(Fd);
			}
		}
		closedir(Dir);

		//! Correct pointer offsets
		uint32_t n;
		for(n=nInbuiltTracks;n<nAllocTracks;n++) {
#define FIX_PTR(AlwaysFix, x) if(AlwaysFix || x) x = (void*)(DataBuffer + (uint32_t)x)
			FIX_PTR(0, TrackListings[n].TrackName);
			FIX_PTR(0, TrackListings[n].Artist);
			FIX_PTR(1, TrackListings[n].Filename);
			FIX_PTR(0, TrackListings[n].CoverArt);
#undef FIX_PTR
		}

	}

	//! Sort the external tracks and insert separators between each artist
	SortTracks(TrackListing_SongsOrder, TrackListing_ArtistsOrder, TrackListings, nAllocTracks, nInbuiltTracks, MaxListings);
	uint32_t nArtists = 0; {
		//! This... is really sub-optimal, but it's easy
		uint16_t *Cur = TrackListing_ArtistsOrder;
		uint16_t *End = Cur + nAllocTracks;
		uint16_t *MaxEnd = Cur + MaxListings;
		const char *LastArtist = NULL;
		while(Cur < End && End < MaxEnd) {
			const char *ThisArtist = TrackListings[*Cur].Artist;

			//! If the artist doesn't match, clear LastArtist
			if(ThisArtist && LastArtist) {
				if(strcmp(LastArtist, ThisArtist)) LastArtist = NULL;
			}

			//! Need to insert a separator?
			if(!ThisArtist || !LastArtist) {
				memmove(Cur+1, Cur, sizeof(uint16_t)*(End-Cur));
				*Cur++ = 0xFFFF, End++;
				LastArtist = ThisArtist;
				nArtists++;
				if(!ThisArtist) break; //! Early exit when hitting the unknown artists
			}
			Cur++;
		}
	}

	//! Return final tracks allocated
	return nAllocTracks | (nAllocTracks+nArtists)<<16;
}

/**************************************/
//! EOF
/**************************************/
