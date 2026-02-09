use bevy_derive::{Deref, DerefMut};
use bevy_ecs::prelude::*;
use bevy_log::prelude::*;
use bevy_render::{
    Extract,
    render_asset::RenderAssets,
    render_graph::{self, NodeRunError, RenderGraphContext, RenderLabel},
    render_resource::{
        CommandEncoderDescriptor, MapMode, PollType, TexelCopyBufferInfo, TexelCopyBufferLayout,
    },
    renderer::{RenderContext, RenderDevice, RenderQueue},
};
use std::sync::atomic::Ordering;

use crate::capture::{Capture, ReleaseBufferSignal, SendBufferJob, WorkerSendBuffer};

use super::RenderViewport;

#[derive(Clone, Default, Resource, Deref, DerefMut)]
pub(super) struct Viewports(Vec<RenderViewport>);

/// Extracting [`RenderViewport`]s into render world, because [`SurfaceNode`] accesses them
pub fn viewport_extract(
    added_viewports: Query<&RenderViewport, Added<RenderViewport>>,
    mut viewports: ResMut<Viewports>,
) {
    viewports.extend(added_viewports.iter().cloned());
}

/// `RenderGraph` label for [`SurfaceNode`]
#[derive(Debug, PartialEq, Eq, Clone, Hash, RenderLabel)]
pub struct SurfaceLabel;

/// `RenderGraph` node
#[derive(Default)]
pub struct SurfaceNode;

// Copies image content from render target to buffer
impl render_graph::Node for SurfaceNode {
    fn run(
        &self,
        _graph: &mut RenderGraphContext,
        _render_context: &mut RenderContext,
        world: &World,
    ) -> Result<(), NodeRunError> {
        let viewports = world.resource::<Viewports>();
        info!("RUNNING SURFACE NODE with {} viewports", viewports.len());
        // let gpu_images = world.resource::<RenderAssets<bevy_render::texture::GpuImage>>();
        //
        // let mut encoder = render_context
        //     .render_device()
        //     .create_command_encoder(&CommandEncoderDescriptor::default());

        for viewport in viewports.iter() {

        }

        Ok(())
    }
}

// pub fn receive_image_from_buffer(
//     mut viewports: ResMut<Viewports>,
//     render_device: Res<RenderDevice>,
//     worker: Res<WorkerSendBuffer>,
// ) {
//     for (capture_idx, capture) in viewports.0.iter_mut().enumerate() {
//         if !capture.enabled() {
//             continue;
//         }
//
//         let skip = capture.skip.load(Ordering::Acquire);
//         if skip {
//             // info!("Skipping frame");
//             continue;
//         }
//
//         let current = capture.current.load(Ordering::Acquire);
//         let buf = &capture.buffers[current];
//
//         let slice = buf.buffer.slice(..);
//
//         slice.map_async(MapMode::Read, {
//             let buffer = buf.buffer.clone();
//             let encoder = capture.encoder.clone();
//             let in_use = buf.in_use.clone();
//             let worker_tx = worker.tx.clone();
//             move |result| match result {
//                 Ok(_) => {
//                     let job = SendBufferJob {
//                         buffer,
//                         encoder,
//                         capture_idx,
//                         buffer_idx: current,
//                     };
//                     if let Err(e) = worker_tx.send(job) {
//                         error!("Worker channel closed: {:?}", e);
//                     }
//                 }
//                 Err(err) => {
//                     error!("Failed to map buffer: {err}");
//                     in_use.store(false, Ordering::Release);
//                 }
//             }
//         });
//
//         if let Err(e) = render_device.poll(PollType::Poll) {
//             error!("Failed to poll render  device: {:?}", e);
//         }
//     }
// }
//
// pub fn release_mapped_buffers(
//     captures: Res<Captures>,
//     release_buffer_signal: Res<ReleaseBufferSignal>,
// ) {
//     while let Ok(signal) = release_buffer_signal.rx.try_recv() {
//         let capture = &captures[signal.capture_idx];
//         let buf = &capture.buffers[signal.buffer_idx];
//         buf.buffer.unmap();
//         buf.in_use.store(false, Ordering::Release);
//     }
// }
