/*
 *  Copyright 2004 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#include "pc/srtp_session.h"

#include <string.h>

#include <string>

#include "media/base/fake_rtp.h"
#include "pc/test/srtp_test_util.h"
#include "rtc_base/byte_order.h"
#include "rtc_base/ssl_stream_adapter.h"  // For rtc::SRTP_*
#include "system_wrappers/include/metrics.h"
#include "test/gmock.h"
#include "test/gtest.h"
#include "test/scoped_key_value_config.h"
#include "third_party/libsrtp/include/srtp.h"

using ::testing::ElementsAre;
using ::testing::Pair;

namespace rtc {

std::vector<int> kEncryptedHeaderExtensionIds;

class SrtpSessionTest : public ::testing::Test {
 public:
  SrtpSessionTest() : s1_(field_trials_), s2_(field_trials_) {
    webrtc::metrics::Reset();
  }

 protected:
  virtual void SetUp() {
    rtp_len_ = sizeof(kPcmuFrame);
    rtcp_len_ = sizeof(kRtcpReport);
    memcpy(rtp_packet_, kPcmuFrame, rtp_len_);
    memcpy(rtcp_packet_, kRtcpReport, rtcp_len_);
  }
  void TestProtectRtp(int crypto_suite) {
    int out_len = 0;
    EXPECT_TRUE(
        s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));
    EXPECT_EQ(out_len, rtp_len_ + rtp_auth_tag_len(crypto_suite));
    EXPECT_NE(0, memcmp(rtp_packet_, kPcmuFrame, rtp_len_));
    rtp_len_ = out_len;
  }
  void TestProtectRtcp(int crypto_suite) {
    int out_len = 0;
    EXPECT_TRUE(s1_.ProtectRtcp(rtcp_packet_, rtcp_len_, sizeof(rtcp_packet_),
                                &out_len));
    EXPECT_EQ(out_len,
              rtcp_len_ + 4 + rtcp_auth_tag_len(crypto_suite));  // NOLINT
    EXPECT_NE(0, memcmp(rtcp_packet_, kRtcpReport, rtcp_len_));
    rtcp_len_ = out_len;
  }
  void TestUnprotectRtp(int crypto_suite) {
    int out_len = 0, expected_len = sizeof(kPcmuFrame);
    EXPECT_TRUE(s2_.UnprotectRtp(rtp_packet_, rtp_len_, &out_len));
    EXPECT_EQ(expected_len, out_len);
    EXPECT_EQ(0, memcmp(rtp_packet_, kPcmuFrame, out_len));
  }
  void TestUnprotectRtcp(int crypto_suite) {
    int out_len = 0, expected_len = sizeof(kRtcpReport);
    EXPECT_TRUE(s2_.UnprotectRtcp(rtcp_packet_, rtcp_len_, &out_len));
    EXPECT_EQ(expected_len, out_len);
    EXPECT_EQ(0, memcmp(rtcp_packet_, kRtcpReport, out_len));
  }
  webrtc::test::ScopedKeyValueConfig field_trials_;
  cricket::SrtpSession s1_;
  cricket::SrtpSession s2_;
  char rtp_packet_[sizeof(kPcmuFrame) + 10];
  char rtcp_packet_[sizeof(kRtcpReport) + 4 + 10];
  int rtp_len_;
  int rtcp_len_;
};

// Test that we can set up the session and keys properly.
TEST_F(SrtpSessionTest, TestGoodSetup) {
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
}

// Test that we can't change the keys once set.
TEST_F(SrtpSessionTest, TestBadSetup) {
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  EXPECT_FALSE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey2,
                           kEncryptedHeaderExtensionIds));
  EXPECT_FALSE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey2,
                              kEncryptedHeaderExtensionIds));
}

// Test that we fail keys of the wrong length.
TEST_F(SrtpSessionTest, TestKeysTooShort) {
  EXPECT_FALSE(s1_.SetSend(kSrtpAes128CmSha1_80,
                           rtc::ZeroOnFreeBuffer<uint8_t>(kTestKey1.data(), 1),
                           kEncryptedHeaderExtensionIds));
  EXPECT_FALSE(s2_.SetReceive(
      kSrtpAes128CmSha1_80, rtc::ZeroOnFreeBuffer<uint8_t>(kTestKey1.data(), 1),
      kEncryptedHeaderExtensionIds));
}

// Test that we can encrypt and decrypt RTP/RTCP using AES_CM_128_HMAC_SHA1_80.
TEST_F(SrtpSessionTest, TestProtect_AES_CM_128_HMAC_SHA1_80) {
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  TestProtectRtp(kSrtpAes128CmSha1_80);
  TestProtectRtcp(kSrtpAes128CmSha1_80);
  TestUnprotectRtp(kSrtpAes128CmSha1_80);
  TestUnprotectRtcp(kSrtpAes128CmSha1_80);
}

// Test that we can encrypt and decrypt RTP/RTCP using AES_CM_128_HMAC_SHA1_32.
TEST_F(SrtpSessionTest, TestProtect_AES_CM_128_HMAC_SHA1_32) {
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_32, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_32, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  TestProtectRtp(kSrtpAes128CmSha1_32);
  TestProtectRtcp(kSrtpAes128CmSha1_32);
  TestUnprotectRtp(kSrtpAes128CmSha1_32);
  TestUnprotectRtcp(kSrtpAes128CmSha1_32);
}

TEST_F(SrtpSessionTest, TestGetSendStreamPacketIndex) {
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_32, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  int64_t index;
  int out_len = 0;
  EXPECT_TRUE(s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_),
                             &out_len, &index));
  // `index` will be shifted by 16.
  int64_t be64_index = static_cast<int64_t>(NetworkToHost64(1 << 16));
  EXPECT_EQ(be64_index, index);
}

// Test that we fail to unprotect if someone tampers with the RTP/RTCP paylaods.
TEST_F(SrtpSessionTest, TestTamperReject) {
  int out_len;
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  TestProtectRtp(kSrtpAes128CmSha1_80);
  TestProtectRtcp(kSrtpAes128CmSha1_80);
  rtp_packet_[0] = 0x12;
  rtcp_packet_[1] = 0x34;
  EXPECT_FALSE(s2_.UnprotectRtp(rtp_packet_, rtp_len_, &out_len));
  EXPECT_METRIC_THAT(
      webrtc::metrics::Samples("WebRTC.PeerConnection.SrtpUnprotectError"),
      ElementsAre(Pair(srtp_err_status_bad_param, 1)));
  EXPECT_FALSE(s2_.UnprotectRtcp(rtcp_packet_, rtcp_len_, &out_len));
  EXPECT_METRIC_THAT(
      webrtc::metrics::Samples("WebRTC.PeerConnection.SrtcpUnprotectError"),
      ElementsAre(Pair(srtp_err_status_auth_fail, 1)));
}

// Test that we fail to unprotect if the payloads are not authenticated.
TEST_F(SrtpSessionTest, TestUnencryptReject) {
  int out_len;
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  EXPECT_FALSE(s2_.UnprotectRtp(rtp_packet_, rtp_len_, &out_len));
  EXPECT_METRIC_THAT(
      webrtc::metrics::Samples("WebRTC.PeerConnection.SrtpUnprotectError"),
      ElementsAre(Pair(srtp_err_status_auth_fail, 1)));
  EXPECT_FALSE(s2_.UnprotectRtcp(rtcp_packet_, rtcp_len_, &out_len));
  EXPECT_METRIC_THAT(
      webrtc::metrics::Samples("WebRTC.PeerConnection.SrtcpUnprotectError"),
      ElementsAre(Pair(srtp_err_status_cant_check, 1)));
}

// Test that we fail when using buffers that are too small.
TEST_F(SrtpSessionTest, TestBuffersTooSmall) {
  int out_len;
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_FALSE(s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_) - 10,
                              &out_len));
  EXPECT_FALSE(s1_.ProtectRtcp(rtcp_packet_, rtcp_len_,
                               sizeof(rtcp_packet_) - 14, &out_len));
}

TEST_F(SrtpSessionTest, TestReplay) {
  static const uint16_t kMaxSeqnum = static_cast<uint16_t>(-1);
  static const uint16_t seqnum_big = 62275;
  static const uint16_t seqnum_small = 10;
  static const uint16_t replay_window = 1024;
  int out_len;

  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));

  // Initial sequence number.
  SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2, seqnum_big);
  EXPECT_TRUE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));

  // Replay within the 1024 window should succeed.
  SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2,
          seqnum_big - replay_window + 1);
  EXPECT_TRUE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));

  // Replay out side of the 1024 window should fail.
  SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2,
          seqnum_big - replay_window - 1);
  EXPECT_FALSE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));

  // Increment sequence number to a small number.
  SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2, seqnum_small);
  EXPECT_TRUE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));

  // Replay around 0 but out side of the 1024 window should fail.
  SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2,
          kMaxSeqnum + seqnum_small - replay_window - 1);
  EXPECT_FALSE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));

  // Replay around 0 but within the 1024 window should succeed.
  for (uint16_t seqnum = 65000; seqnum < 65003; ++seqnum) {
    SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2, seqnum);
    EXPECT_TRUE(
        s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));
  }

  // Go back to normal sequence nubmer.
  // NOTE: without the fix in libsrtp, this would fail. This is because
  // without the fix, the loop above would keep incrementing local sequence
  // number in libsrtp, eventually the new sequence number would go out side
  // of the window.
  SetBE16(reinterpret_cast<uint8_t*>(rtp_packet_) + 2, seqnum_small + 1);
  EXPECT_TRUE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));
}

TEST_F(SrtpSessionTest, RemoveSsrc) {
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  int out_len;
  // Encrypt and decrypt the packet once.
  EXPECT_TRUE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));
  EXPECT_TRUE(s2_.UnprotectRtp(rtp_packet_, out_len, &out_len));
  EXPECT_EQ(rtp_len_, out_len);
  EXPECT_EQ(0, memcmp(rtp_packet_, kPcmuFrame, out_len));

  // Recreate the original packet and encrypt again.
  memcpy(rtp_packet_, kPcmuFrame, rtp_len_);
  EXPECT_TRUE(
      s1_.ProtectRtp(rtp_packet_, rtp_len_, sizeof(rtp_packet_), &out_len));
  // Attempting to decrypt will fail as a replay attack.
  // (srtp_err_status_replay_fail) since the sequence number was already seen.
  EXPECT_FALSE(s2_.UnprotectRtp(rtp_packet_, out_len, &out_len));

  // Remove the fake packet SSRC 1 from the session.
  EXPECT_TRUE(s2_.RemoveSsrcFromSession(1));
  EXPECT_FALSE(s2_.RemoveSsrcFromSession(1));

  // Since the SRTP state was discarded, this is no longer a replay attack.
  EXPECT_TRUE(s2_.UnprotectRtp(rtp_packet_, out_len, &out_len));
  EXPECT_EQ(rtp_len_, out_len);
  EXPECT_EQ(0, memcmp(rtp_packet_, kPcmuFrame, out_len));
  EXPECT_TRUE(s2_.RemoveSsrcFromSession(1));
}

TEST_F(SrtpSessionTest, ProtectUnprotectWrapAroundRocMismatch) {
  // This unit tests demonstrates why you should be careful when
  // choosing the initial RTP sequence number as there can be decryption
  // failures when it wraps around with packet loss. Pick your starting
  // sequence number in the lower half of the range for robustness reasons,
  // see packet_sequencer.cc for the code doing so.
  EXPECT_TRUE(s1_.SetSend(kSrtpAes128CmSha1_80, kTestKey1,
                          kEncryptedHeaderExtensionIds));
  EXPECT_TRUE(s2_.SetReceive(kSrtpAes128CmSha1_80, kTestKey1,
                             kEncryptedHeaderExtensionIds));
  // Buffers include enough room for the 10 byte SRTP auth tag so we can
  // encrypt in place.
  unsigned char kFrame1[] = {
      // clang-format off
      // PT=0, SN=65535, TS=0, SSRC=1
      0x80, 0x00, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
      0xBE, 0xEF,  // data bytes
      // Space for the SRTP auth tag
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      // clang-format on
  };
  unsigned char kFrame2[] = {
      // clang-format off
      // PT=0, SN=1, TS=0, SSRC=1
      0x80, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
      0xBE, 0xEF,  // data bytes
      // Space for the SRTP auth tag
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      // clang-format on
  };

  int out_len;
  // Encrypt the frames in-order. There is a sequence number rollover from
  // 65535 to 1 (skipping 0) and the second packet gets encrypted with a
  // roll-over counter (ROC) of 1. See
  // https://datatracker.ietf.org/doc/html/rfc3711#section-3.3.1
  EXPECT_TRUE(
      s1_.ProtectRtp(kFrame1, sizeof(kFrame1) - 10, sizeof(kFrame1), &out_len));
  EXPECT_EQ(out_len, 24);
  EXPECT_TRUE(
      s1_.ProtectRtp(kFrame2, sizeof(kFrame2) - 10, sizeof(kFrame2), &out_len));
  EXPECT_EQ(out_len, 24);

  // If we decrypt frame 2 first it will have a ROC of 1 but the receiver
  // does not know this is a rollover so will attempt with a ROC of 0.
  // Note: If libsrtp is modified to attempt to decrypt with ROC=1 for this
  // case, this test will fail and needs to be modified accordingly to unblock
  // the roll. See https://issues.webrtc.org/353565743 for details.
  EXPECT_FALSE(s2_.UnprotectRtp(kFrame2, sizeof(kFrame2), &out_len));
  // Decrypt frame 1.
  EXPECT_TRUE(s2_.UnprotectRtp(kFrame1, sizeof(kFrame1), &out_len));
  // Now decrypt frame 2 again. A rollover is detected which increases
  // the ROC to 1 so this succeeds.
  EXPECT_TRUE(s2_.UnprotectRtp(kFrame2, sizeof(kFrame2), &out_len));
}

}  // namespace rtc
