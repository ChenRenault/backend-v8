VERSION=$1
[ -z "$GITHUB_WORKSPACE" ] && GITHUB_WORKSPACE="$( cd "$( dirname "$0" )"/.. && pwd )"

cd ~
echo "=====[ Getting Depot Tools ]====="	
git clone -q https://chromium.googlesource.com/chromium/tools/depot_tools.git
cd depot_tools
git reset --hard 8d16d4a
cd ..
export DEPOT_TOOLS_UPDATE=0
export PATH=$(pwd)/depot_tools:$PATH
gclient


mkdir v8
cd v8

echo "=====[ Fetching V8 ]====="
fetch v8
echo "target_os = ['linux-arm64']" >> .gclient
cd ~/v8/v8
git checkout refs/tags/$VERSION
gclient sync

# echo "=====[ Patching V8 ]====="
# git apply --cached $GITHUB_WORKSPACE/patches/builtins-puerts.patches
# git checkout -- .

echo "=====[ Patching V8 ]====="
echo "=====[ --Runtime Trace Hook ]====="
node $GITHUB_WORKSPACE/node-script/do-gitpatch.js -p $GITHUB_WORKSPACE/patches/runtime_trace_hook.patch

echo "=====[ add ArrayBuffer_New_Without_Stl ]====="
node $GITHUB_WORKSPACE/node-script/add_arraybuffer_new_without_stl.js .

python build/linux/sysroot_scripts/install-sysroot.py --arch=arm64

echo "=====[ Building V8 ]====="
python ./tools/dev/v8gen.py arm64.release -vv -- '
is_debug = false
target_cpu = "arm64"
v8_target_cpu = "arm64"
v8_enable_i18n_support= false
v8_use_snapshot = true
v8_use_external_startup_data = true
v8_static_library = true
strip_debug_info = true
symbol_level=0
libcxx_abi_unstable = false
v8_enable_pointer_compression=false
'

ninja -C out.gn/arm64.release -t clean
ninja -C out.gn/arm64.release wee8

node $GITHUB_WORKSPACE/node-script/genBlobHeader.js "Linux_arm64" out.gn/arm64.release/snapshot_blob.bin

mkdir -p output/v8/Lib/Linux_arm64
cp out.gn/arm64.release/obj/libwee8.a output/v8/Lib/Linux_arm64/
mkdir -p output/v8/Inc/Blob/Linux_arm64
cp SnapshotBlob.h output/v8/Inc/Blob/Linux_arm64/

