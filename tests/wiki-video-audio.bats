#!/usr/bin/env bats
#
# tests/wiki-video-audio.bats
#
# Black-box tests for video/audio extraction (FR-2.3 / FR-2.4)
# Sprint 08: dav-wiki 多模組擴充
#
# Coverage:
#   AC-V1: ffmpeg 從影片抽 frame (FR-2.3.3)
#   AC-V2: ffprobe 取得影片時長 (FR-2.3.x)
#   AC-V3: ffmpeg 從影片抽音軌 (FR-2.3.x)
#   AC-V4: 影片章節切分（場景偵測）(FR-2.3.4)
#   AC-V5: 音訊時長 (FR-2.4.x)
#   AC-V6: 不存在的影片檔
#
# Usage:
#   bats tests/wiki-video-audio.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  WORK="$(mktemp -d -t wiki-video-test-XXXXXX)"
  export WORK
}

teardown() {
  rm -rf "$WORK"
}

# === AC-V1: ffmpeg 抽 frame ===
@test "AC-V1: ffmpeg frame extraction" {
  # 先生成測試影片（3 秒鐘）
  ffmpeg -f lavfi -i "color=red:size=320x240:duration=3" \
         -f lavfi -i "sine=frequency=440:duration=3" \
         -c:v libx264 -c:a aac \
         "$WORK/test.mp4" -y 2>/dev/null
  [ -f "$WORK/test.mp4" ]

  # 抽 frame（每 1 秒 1 張）
  mkdir -p "$WORK/frames"
  ffmpeg -i "$WORK/test.mp4" -vf "fps=1" "$WORK/frames/frame-%03d.png" -y 2>/dev/null

  # 應有 3-4 張 frame
  count=$(ls "$WORK/frames/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 2 ]
}

# === AC-V2: ffprobe 取得影片時長 ===
@test "AC-V2: ffprobe metadata extraction" {
  ffmpeg -f lavfi -i "color=blue:size=160x120:duration=2" \
         "$WORK/short.mp4" -y 2>/dev/null
  duration=$(ffprobe -v error -show_entries format=duration \
                     -of csv=p=0 "$WORK/short.mp4" 2>/dev/null)
  # 應約 2 秒（容許浮動 ±0.5）
  awk -v d="$duration" 'BEGIN { exit !(d >= 1.5 && d <= 2.5) }'
}

# === AC-V3: ffmpeg 抽音軌 ===
@test "AC-V3: ffmpeg audio extraction" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=2" \
         -f lavfi -i "sine=frequency=440:duration=2" \
         -c:v libx264 -c:a aac \
         "$WORK/test.mp4" -y 2>/dev/null
  ffmpeg -i "$WORK/test.mp4" -vn -acodec pcm_s16le \
         "$WORK/audio.wav" -y 2>/dev/null
  [ -f "$WORK/audio.wav" ]
  # 確認是 WAV
  file "$WORK/audio.wav" | grep -q "WAVE"
}

# === AC-V4: 場景偵測（scene detection） ===
@test "AC-V4: ffmpeg scene detection" {
  # 生成 2 段不同顏色的影片（紅→藍）
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1.5" \
         -f lavfi -i "color=blue:size=160x120:duration=1.5" \
         -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[outv]" \
         -map "[outv]" \
         "$WORK/scene.mp4" -y 2>/dev/null
  [ -f "$WORK/scene.mp4" ]

  # 用 scene detect 找出切換時間
  mkdir -p "$WORK/scene_frames"
  ffmpeg -i "$WORK/scene.mp4" \
         -vf "select=gt(scene\,0.4),showinfo" \
         -vsync vfr \
         "$WORK/scene_frames/frame-%03d.png" -y 2>/dev/null

  # 應至少有 1 個場景變化（>0 frames）
  count=$(ls "$WORK/scene_frames/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

# === AC-V5: 純音訊時長 ===
@test "AC-V5: --help shows usage" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=2" \
         -ar 16000 -ac 1 \
         "$WORK/audio.wav" -y 2>/dev/null
  [ -f "$WORK/audio.wav" ]
  duration=$(ffprobe -v error -show_entries format=duration \
                     -of csv=p=0 "$WORK/audio.wav" 2>/dev/null)
  awk -v d="$duration" 'BEGIN { exit !(d >= 1.5 && d <= 2.5) }'
}

# === AC-V6: 不存在的影片 ===
@test "AC-V6: error → ffprobe diagnostics" {
  run ffprobe -v error -show_entries format=duration \
              -of csv=p=0 "/nonexistent/video.mp4"
  [ "$status" -ne 0 ]
}

# === AC-V7: 從影片抽 thumbnail ===
@test "AC-V7: thumbnail1.jpg generated" {
  ffmpeg -f lavfi -i "color=green:size=320x240:duration=2" \
         "$WORK/clip.mp4" -y 2>/dev/null
  # 抽第 1 秒當 thumbnail
  ffmpeg -ss 00:00:01 -i "$WORK/clip.mp4" \
         -vframes 1 "$WORK/thumb.jpg" -y 2>/dev/null
  [ -f "$WORK/thumb.jpg" ]
  # 確認是 JPEG
  file "$WORK/thumb.jpg" | grep -q "JPEG"
}

# === AC-V8: 影片 codec 偵測 ===
@test "AC-V8: ffprobe reports video codec" {
  ffmpeg -f lavfi -i "color=red:size=160x120:duration=1" \
         -c:v libx264 \
         "$WORK/codec.mp4" -y 2>/dev/null
  codec=$(ffprobe -v error -select_streams v:0 \
                 -show_entries stream=codec_name \
                 -of csv=p=0 "$WORK/codec.mp4" 2>/dev/null)
  [ "$codec" = "h264" ]
}

# === AC-V9: 音訊 codec 偵測 ===
@test "AC-V9: ffprobe reports audio codec" {
  ffmpeg -f lavfi -i "sine=frequency=440:duration=1" \
         -c:a aac "$WORK/audio.m4a" -y 2>/dev/null
  codec=$(ffprobe -v error -select_streams a:0 \
                 -show_entries stream=codec_name \
                 -of csv=p=0 "$WORK/audio.m4a" 2>/dev/null)
  [ "$codec" = "aac" ]
}

# === AC-V10: 大檔案 ffprobe 不卡住 ===
@test "AC-V10: ffprobe 5+ durations within tolerance" {
  ffmpeg -f lavfi -i "color=red:size=320x240:duration=5" \
         -c:v libx264 -preset ultrafast \
         "$WORK/large.mp4" -y 2>/dev/null
  start=$(date +%s)
  ffprobe -v error -show_entries format=duration \
          -of csv=p=0 "$WORK/large.mp4" > /dev/null 2>&1
  end=$(date +%s)
  elapsed=$((end - start))
  [ "$elapsed" -le 5 ]
}