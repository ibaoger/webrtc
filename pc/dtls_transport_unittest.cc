/*
 *  Copyright 2018 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#include "pc/dtls_transport.h"

#include <utility>
#include <vector>

#include "absl/memory/memory.h"
#include "p2p/base/fake_dtls_transport.h"
#include "rtc_base/gunit.h"
#include "test/gmock.h"
#include "test/gtest.h"

constexpr int kDefaultTimeout = 1000;  // milliseconds

using cricket::FakeDtlsTransport;
using ::testing::ElementsAre;

namespace webrtc {

class TestDtlsTransportObserver : public DtlsTransportObserverInterface {
 public:
  void OnStateChange(DtlsTransportInformation info) override {
    state_change_called_ = true;
    states_.push_back(info.state());
  }

  void OnError(RTCError error) override {}

  DtlsTransportState state() {
    if (states_.size() > 0) {
      return states_[states_.size() - 1];
    } else {
      return DtlsTransportState::kNew;
    }
  }

  bool state_change_called_ = false;
  std::vector<DtlsTransportState> states_;
};

class DtlsTransportTest : public testing::Test {
 public:
  DtlsTransport* transport() { return transport_.get(); }
  DtlsTransportObserverInterface* observer() { return &observer_; }

  void CreateTransport() {
    auto cricket_transport = absl::make_unique<FakeDtlsTransport>(
        "audio", cricket::ICE_CANDIDATE_COMPONENT_RTP);
    transport_ =
        new rtc::RefCountedObject<DtlsTransport>(std::move(cricket_transport));
  }

  void CompleteDtlsHandshake() {
    auto fake_dtls1 = static_cast<FakeDtlsTransport*>(transport_->internal());
    auto fake_dtls2 = absl::make_unique<FakeDtlsTransport>(
        "audio", cricket::ICE_CANDIDATE_COMPONENT_RTP);
    auto cert1 = rtc::RTCCertificate::Create(absl::WrapUnique(
        rtc::SSLIdentity::Generate("session1", rtc::KT_DEFAULT)));
    fake_dtls1->SetLocalCertificate(cert1);
    auto cert2 = rtc::RTCCertificate::Create(absl::WrapUnique(
        rtc::SSLIdentity::Generate("session1", rtc::KT_DEFAULT)));
    fake_dtls2->SetLocalCertificate(cert2);
    fake_dtls1->SetDestination(fake_dtls2.get());
  }

  rtc::scoped_refptr<DtlsTransport> transport_;
  TestDtlsTransportObserver observer_;
};

TEST_F(DtlsTransportTest, CreateClearDelete) {
  auto cricket_transport = absl::make_unique<FakeDtlsTransport>(
      "audio", cricket::ICE_CANDIDATE_COMPONENT_RTP);
  rtc::scoped_refptr<DtlsTransport> webrtc_transport =
      new rtc::RefCountedObject<DtlsTransport>(std::move(cricket_transport));
  ASSERT_TRUE(webrtc_transport->internal());
  ASSERT_EQ(DtlsTransportState::kNew, webrtc_transport->Information().state());
  webrtc_transport->Clear();
  ASSERT_FALSE(webrtc_transport->internal());
  ASSERT_EQ(DtlsTransportState::kClosed,
            webrtc_transport->Information().state());
}

TEST_F(DtlsTransportTest, EventsObservedWhenConnecting) {
  CreateTransport();
  transport()->RegisterObserver(observer());
  CompleteDtlsHandshake();
  ASSERT_TRUE_WAIT(observer_.state_change_called_, kDefaultTimeout);
  EXPECT_THAT(
      observer_.states_,
      ElementsAre(  // FakeDtlsTransport doesn't signal the "connecting" state.
                    // TODO(hta): fix FakeDtlsTransport or file bug on it.
                    // DtlsTransportState::kConnecting,
          DtlsTransportState::kConnected));
}

TEST_F(DtlsTransportTest, CloseWhenClearing) {
  CreateTransport();
  transport()->RegisterObserver(observer());
  CompleteDtlsHandshake();
  ASSERT_TRUE_WAIT(observer_.state() == DtlsTransportState::kConnected,
                   kDefaultTimeout);
  transport()->Clear();
  ASSERT_TRUE_WAIT(observer_.state() == DtlsTransportState::kClosed,
                   kDefaultTimeout);
}

}  // namespace webrtc
