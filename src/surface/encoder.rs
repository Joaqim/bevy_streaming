use anyhow::Result;
use bevy_log::prelude::*;
use derive_more::derive::{Display, Error};
use gst::CapsFeatures;
use gst::prelude::*;
use gst_base::prelude::BaseSrcExt;
use gstrswebrtc::{
    signaller::{Signallable, Signaller},
    webrtcsink::{self, BaseWebRTCSink, WebRTCSinkCongestionControl},
};

use crate::gst_webrtc_encoder::ErrorMessage;
#[cfg(feature = "pixelstreaming")]
use crate::pixelstreaming::signaller::UePsSignaller;
use crate::{CongestionControl, GstWebRtcSettings, SignallingServer, encoder::StreamEncoder};

#[derive(Clone)]
pub struct GstWebRtcDmabufEncoder {
    #[allow(dead_code)]
    settings: GstWebRtcSettings,
    pipeline: gst::Pipeline,
    pub appsrc: gst_app::AppSrc,
    pub webrtcsink: BaseWebRTCSink,
}

impl GstWebRtcDmabufEncoder {
    pub fn with_settings(settings: GstWebRtcSettings) -> Result<Self> {
        gst::init()?;

        let pipeline = gst::Pipeline::default();

        // let video_info = gst_video::VideoInfo::builder(
        //     gst_video::VideoFormat::Rgba,
        //     settings.width,
        //     settings.height,
        // )
        // .build()
        // .expect("Failed to create video info");
        //
        // let mut caps = video_info.to_caps()?;
        // caps.make_mut().set_features_simple(Some(CapsFeatures::new(["memory:DMABuf"])));
        //
        // info!("Video info caps: {:#?}", caps);

        let appsrc = gst_app::AppSrc::builder()
            .name("appsrc")
            .do_timestamp(true)
            .is_live(true)
            // .caps(&caps)
            // .format(gst::Format::Bytes)
            .format(gst::Format::Time)
            // Allocate space for 1 buffer
            // .max_bytes((settings.width * settings.height * 4).into())
            .max_buffers(1)
            .build();

        let queue = gst::ElementFactory::make("queue").build()?;
        queue.set_property_from_str("leaky", "downstream");
        queue.set_property("max-size-buffers", 1u32);

        let glupload = gst::ElementFactory::make("glupload").build()?;

        let glcolorconvert = gst::ElementFactory::make("glcolorconvert").build()?;
        let glcolorconvert_capsfilter = gst::ElementFactory::make("capsfilter").build()?;

        let glcolorconvert_caps = gst::Caps::builder("video/x-raw")
            .features(["memory:GLMemory"])
            .field("format", "BGRA")
            .build();

        glcolorconvert_capsfilter.set_property("caps", &glcolorconvert_caps);


        // let glcolorconvert_rgba = gst::ElementFactory::make("glcolorconvert").build()?;
        // let glcolorconvert_capsfilter_rgba = gst::ElementFactory::make("capsfilter").build()?;
        //
        // let glcolorconvert_caps_rgba = gst::Caps::builder("video/x-raw")
        //     .features(["memory:GLMemory"])
        //     .field("format", "RGBA")
        //     .build();
        //
        // glcolorconvert_capsfilter_rgba.set_property("caps", &glcolorconvert_caps_rgba);


        let gleffects = gst::ElementFactory::make("gleffects").build()?;
        gleffects.set_property_from_str("effect", "identity");

        let encoder = gst::ElementFactory::make("nvh264enc").build()?;
        encoder.set_property("bitrate", 2048000_u32 / 1000);
        encoder.set_property("gop-size", 2560i32);
        encoder.set_property_from_str("rc-mode", "cbr-ld-hq");
        encoder.set_property("zerolatency", true);
        // encoder.set_property_from_str("preset", "low-latency-hq");

        let encoder_caps = gst::Caps::builder("video/x-h264")
            .field("stream-format", "avc") // Format standard pour RTP/WebRTC
            .field("profile", "constrained-baseline") // Format standard pour RTP/WebRTC
            .build();

        let encoder_capsfilter = gst::ElementFactory::make("capsfilter").build()?;
        encoder_capsfilter.set_property("caps", &encoder_caps);

        let h264parse = gst::ElementFactory::make("h264parse").build()?;
        h264parse.set_property("config-interval", -1i32);

        let webrtcsink = BaseWebRTCSink::with_signaller(settings.signalling_server.as_ref().into());

        if let Some(video_caps) = &settings.video_caps {
            webrtcsink.set_property_from_str("video-caps", video_caps);
        }

        // force disable congestion control because webrtcsink does not do encoding
        webrtcsink.set_property("congestion-control", WebRTCSinkCongestionControl::Disabled);

        pipeline.add_many([
            appsrc.upcast_ref(),
            &queue,
            &glupload,
            // &glcolorconvert,
            // &glcolorconvert_capsfilter,
            // &glcolorconvert_rgba,
            // &glcolorconvert_capsfilter_rgba,
            &gleffects,
            &encoder,
            &h264parse,
            &encoder_capsfilter,
            webrtcsink.upcast_ref(),
        ])?;
        gst::Element::link_many([
            appsrc.upcast_ref(),
            &queue,
            &glupload,
            // &glcolorconvert,
            // &glcolorconvert_capsfilter,
            // &glcolorconvert_rgba,
            // &glcolorconvert_capsfilter_rgba,
            &gleffects,
            &encoder,
            &h264parse,
            &encoder_capsfilter,
            webrtcsink.upcast_ref(),
        ])?;

        Ok(Self {
            settings,
            pipeline,
            appsrc,
            webrtcsink,
        })
    }

    pub fn start(&self) -> Result<()> {
        info!("Start pipeline");
        self.pipeline.set_state(gst::State::Playing)?;

        Ok(())
    }

    pub fn process_events(&self) -> Result<()> {
        let bus = self
            .pipeline
            .bus()
            .expect("Pipeline without bus. Shouldn't happen!");

        for msg in bus.iter() {
            use gst::MessageView;

            // info!("Msg: {:#?}", msg.view());
            match msg.view() {
                MessageView::Eos(..) => break,
                MessageView::Error(err) => {
                    self.pipeline.set_state(gst::State::Null)?;
                    return Err(ErrorMessage {
                        src: msg
                            .src()
                            .map(|s| s.path_string())
                            .unwrap_or_else(|| glib::GString::from("UNKNOWN")),
                        error: err.error(),
                        debug: err.debug(),
                    }
                    .into());
                }
                _ => (),
            }
        }

        Ok(())
    }

    pub fn push_buffer(&self, buffer: gst::Buffer) -> Result<()> {
        let _ = self.appsrc.push_buffer(buffer);

        Ok(())
    }
    pub fn finish(self: Box<Self>) {
        self.pipeline.set_state(gst::State::Null).unwrap();
    }
}
