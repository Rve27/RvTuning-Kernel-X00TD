#!/bin/bash

KERNELDIR=$(pwd)

# Identity
CODENAME=Alpha
KERNELNAME=RvTuning
VARIANT=HMP
VERSION=CLO

if ! [ -d "$KERNELDIR/ew" ]; then
if ! git clone --depth=1 https://gitlab.com/Tiktodz/electrowizard-clang.git -b 16 --single-branch ew; then
exit 1
fi
fi

if ! [ -d "$KERNELDIR/AnyKernel3" ]; then
if ! git clone --depth=1 https://github.com/Rve27/AnyKernel3.git -b hmp-old AnyKernel3; then
exit 1
fi
fi

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=X00TD_defconfig
ANYKERNEL3_DIR=$KERNELDIR/AnyKernel3/
TZ=Asia/Jakarta
DATE=$(date '+%Y%m%d')
BUILD_START=$(date +"%s")
FINAL_KERNEL_ZIP="$KERNELNAME-$VERSION-$VARIANT-$(date '+%Y%m%d-%H%M')"
KERVER=$(make kernelversion)

# Exporting
export PATH="$KERNELDIR/ew/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="RvTuning"
export KBUILD_BUILD_HOST="Rve27"
export KBUILD_COMPILER_STRING="$($KERNELDIR/ew/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

# Speed up build process
MAKE="./makeparallel"

# Java
command -v java > /dev/null 2>&1

# Cleaning out
mkdir -p out
make O=out clean

# Starting compilation
make $KERNEL_DEFCONFIG O=out 2>&1 | tee -a error.log
make -j$(nproc --all) O=out LLVM=1 \
		ARCH=arm64 \
		AS="$KERNELDIR/ew/bin/llvm-as" \
		CC="$KERNELDIR/ew/bin/clang" \
		LD="$KERNELDIR/ew/bin/ld.lld" \
		AR="$KERNELDIR/ew/bin/llvm-ar" \
		NM="$KERNELDIR/ew/bin/llvm-nm" \
		STRIP="$KERNELDIR/ew/bin/llvm-strip" \
		OBJCOPY="$KERNELDIR/ew/bin/llvm-objcopy" \
		OBJDUMP="$KERNELDIR/ew/bin/llvm-objdump" \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE="$KERNELDIR/ew/bin/clang" \
		CROSS_COMPILE_COMPAT="$KERNELDIR/ew/bin/clang" \
		CROSS_COMPILE_ARM32="$KERNELDIR/ew/bin/clang" 2>&1 | tee -a error.log

if ! [ -f $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb ];then
    tg_post_build "error.log" "Build Error!"
    exit 1
fi

# Anykernel 3 time!!
ls $ANYKERNEL3_DIR
cp $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR/

cd $ANYKERNEL3_DIR/
cp -af $KERNELDIR/init.$CODENAME.Spectrum.rc spectrum/init.spectrum.rc && sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel TheOneMemory/g" spectrum/init.spectrum.rc
cp -af $KERNELDIR/changelog META-INF/com/google/android/aroma/changelog.txt
cp -af anykernel-real.sh anykernel.sh
sed -i "s/kernel.string=.*/kernel.string=$KERNELNAME/g" anykernel.sh
sed -i "s/kernel.type=.*/kernel.type=$VARIANT/g" anykernel.sh
sed -i "s/kernel.for=.*/kernel.for=$CODENAME/g" anykernel.sh
sed -i "s/kernel.compiler=.*/kernel.compiler=$KBUILD_COMPILER_STRING/g" anykernel.sh
sed -i "s/kernel.made=.*/kernel.made=Rve27/g" anykernel.sh
sed -i "s/kernel.version=.*/kernel.version=$KERVER/g" anykernel.sh
sed -i "s/message.word=.*/message.word=Appreciate your efforts for choosing TheOneMemory kernel./g" anykernel.sh
sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh
sed -i "s/build.type=.*/build.type=$VERSION/g" anykernel.sh
sed -i "s/supported.versions=.*/supported.versions=9-13/g" anykernel.sh
sed -i "s/device.name1=.*/device.name1=X00TD/g" anykernel.sh
sed -i "s/device.name2=.*/device.name2=X00T/g" anykernel.sh
sed -i "s/device.name3=.*/device.name3=Zenfone Max Pro M1 (X00TD)/g" anykernel.sh
sed -i "s/device.name4=.*/device.name4=ASUS_X00TD/g" anykernel.sh
sed -i "s/device.name5=.*/device.name5=ASUS_X00T/g" anykernel.sh
sed -i "s/X00TD=.*/X00TD=1/g" anykernel.sh
cd META-INF/com/google/android
sed -i "s/KNAME/$KERNELNAME/g" aroma-config
sed -i "s/KVER/$KERVER/g" aroma-config
sed -i "s/KAUTHOR/Rve27/g" aroma-config
sed -i "s/KDEVICE/Zenfone Max Pro M1/g" aroma-config
sed -i "s/KBDATE/$DATE/g" aroma-config
sed -i "s/KVARIANT/$VARIANT/g" aroma-config
cd ../../../..

zip -r9 "../$FINAL_KERNEL_ZIP" * -x .git README.md anykernel-real.sh placeholder .gitignore zipsigner* "*.zip"

ZIP_FINAL="$FINAL_KERNEL_ZIP"

cd ..

curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
ZIP_FINAL="$ZIP_FINAL-signed"

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
