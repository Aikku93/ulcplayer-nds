import math
import shutil
import os
import sys
from PIL import Image, ImageDraw

# Supersampling is needed for rounded_rectangle() :/
ssFactor = 8
backdropColour = (32,32,32)

def applyImageBorder(img, borderRadius, backdropColour):
        # This feels really clunky, but it works...
        imgSizeSS = (img.width*ssFactor,img.height*ssFactor)
        maskImg = Image.new(mode = "L", size = imgSizeSS, color = 0)
        maskImgDraw = ImageDraw.Draw(maskImg)
        maskImgDraw.rounded_rectangle((0,0,) + imgSizeSS, fill = 255, radius = int(borderRadius*maskImg.width))
        maskImg = maskImg.resize(img.size, resample=Image.BOX)
        newImg = Image.new(mode = "RGBA", size = img.size, color = backdropColour + (255,))
        return Image.composite(img, newImg, maskImg)

def generateImageBytes(img):
        outData = bytearray()
        for y in range(img.height):
                for x in range(img.width):
                        (r,g,b,a) = img.getpixel((x,y))
                        r >>= 8-5
                        g >>= 8-5
                        b >>= 8-5
                        px = (r | g<<5 | b<<10 | 0x8000)
                        outData.append((px   ) & 0xFF)
                        outData.append((px>>8) & 0xFF)
        return outData

def processCoverArt(trackArtFilename):
        if trackArtFilename == "": return None

        # Ensure we have a square image
        img = Image.open(trackArtFilename)
        if img.width != img.height:
                print("WARNING: Image must be square")
                return None

        # Apply effects
        img = applyImageBorder(img.convert("RGBA"), 1.0/8, backdropColour)

        # Create re-sized images
        img16 = img.resize(size = (16,16), resample = Image.LANCZOS)
        img64 = img.resize(size = (64,64), resample = Image.LANCZOS)

        # Apply corner smoothing and create output
        data16 = generateImageBytes(img16)
        data64 = generateImageBytes(img64)
        return data16 + data64

def mainFunc():
        # Check arguments/display usage
        if len(sys.argv) < 4:
                print("Usage: AddInfo.py Dst.ulc Src.ulc <Options>")
                print("Options must be at least one of:")
                print(" -title:<Title>")
                print(" -artist:<Artist>")
                print(" -art:<Img>")
                print("Remember to enclose arguments in \"quotations\" if they contain spaces.")
                return 1

        # Parse arguments
        dstFile     = sys.argv[1]
        srcFile     = sys.argv[2]
        trackTitle  = ""
        trackArtist = ""
        trackArt    = ""
        for rawArg in sys.argv[3:]:
                [argType,argData] = rawArg.split(':', 1)
                if argData == "": continue
                if argType == "-title":
                        trackTitle = argData
                elif argType == "-artist":
                        trackArtist = argData
                elif argType == "-art":
                        trackArt = argData

        # Process cover art
        trackCoverArtData = processCoverArt(trackArt)

        # Duplicate input file
        shutil.copyfile(srcFile, dstFile)

        # Open new file
        with open(dstFile, "ab") as f:
                alignFile = lambda : f.write(bytearray([0] * (-f.tell() & 3)))
                alignFile()
                if trackTitle != "":
                        beg = f.tell()
                        data = bytearray(bytes(trackTitle, "UTF-8"))
                        data.append(0)
                        f.write(data)
                        alignFile()
                        end = f.tell()
                        sz = end - beg
                        f.write(b"ulcDT\x00")
                        f.write(bytearray([sz&0xFF,(sz>>8)&0xFF]))

                if trackArtist != "":
                        beg = f.tell()
                        data = bytearray(bytes(trackArtist, "UTF-8"))
                        data.append(0)
                        f.write(data)
                        alignFile()
                        end = f.tell()
                        sz = end - beg
                        f.write(b"ulcDT\x01")
                        f.write(bytearray([sz&0xFF,(sz>>8)&0xFF]))

                if trackCoverArtData != None:
                        beg = f.tell()
                        f.write(trackCoverArtData)
                        end = f.tell()
                        sz = end - beg
                        f.write(b"ulcDT\x02")
                        f.write(bytearray([sz&0xFF,(sz>>8)&0xFF]))
        return 0

if __name__ == "__main__":
        mainFunc()
