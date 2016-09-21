// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


import Foundation
import MobileCoreServices
import CocoaLumberjackSwift

@objc public final class FileMetaDataGenerator: NSObject {

    static func metadataForFileAtURL(_ url: URL, UTI uti: String, completion: (ZMFileMetadata) -> ()) {
        SharedPreviewGenerator.generator.generatePreview(url, UTI: uti) { (preview) in
            
            let thumbnail = preview != nil ? UIImageJPEGRepresentation(preview!, 0.9) : nil
            
            if AVURLAsset.wr_isAudioVisualUTI(uti) {
                let asset = AVURLAsset(URL: url)
                
                if let videoTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first {
                    completion(ZMVideoMetadata(fileURL: url, duration: asset.duration.seconds, dimensions: videoTrack.naturalSize, thumbnail: thumbnail))
                } else {
                    let loudness = audioSamplesFromAsset(asset, maxSamples: 100)
                    
                    completion(ZMAudioMetadata(fileURL: url, duration: asset.duration.seconds, normalizedLoudness: loudness ?? []))
                }
            } else {
                completion(ZMFileMetadata(fileURL: url, thumbnail: thumbnail))
            }
        }
    }
    
}

extension AVURLAsset {
    static func wr_isAudioVisualUTI(_ UTI: String) -> Bool {
        return audiovisualTypes().reduce(false) { (conformsBefore: Bool, compatibleUTI: String) -> Bool in
            conformsBefore || UTTypeConformsTo(UTI, compatibleUTI)
        }
    }
}

func audioSamplesFromAsset(_ asset: AVAsset, maxSamples: UInt64) -> [Float]? {
    let assetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first
    let reader: AVAssetReader
    do {
        reader = try AVAssetReader(asset: asset)
    }
    catch let error {
        DDLogError("Cannot read asset metadata for \(asset): \(error)")
        return .None
    }
    
    let outputSettings = [ AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatLinearPCM),
                           AVLinearPCMBitDepthKey : 16,
                           AVLinearPCMIsBigEndianKey : false,
                           AVLinearPCMIsFloatKey : false,
                           AVLinearPCMIsNonInterleaved : false ]
    
    let output = AVAssetReaderTrackOutput(track: assetTrack!, outputSettings: outputSettings)
    output.alwaysCopiesSampleData = false
    reader.addOutput(output)
    var sampleCount : UInt64 = 0
    
    for item in (assetTrack?.formatDescriptions)! {
        let formatDescription  = item as! CMFormatDescription
        let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        sampleCount = UInt64(basicDescription.memory.mSampleRate * Float64(asset.duration.value)/Float64(asset.duration.timescale));
    }
    
    let stride = Int(max(sampleCount / maxSamples, 1))
    var sampleData : [Float] = []
    var sampleSkipCounter = 0
    
    reader.startReading()
    
    while (reader.status == .Reading) {
        if let sampleBuffer = output.copyNextSampleBuffer() {
            var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 0, mDataByteSize: 0, mData: nil))
            var buffer : CMBlockBuffer?
            var bufferSize = 0
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, &bufferSize, nil, 0, nil, nil, 0, nil)
            
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                    nil,
                                                                    &audioBufferList,
                                                                    bufferSize,
                                                                    nil,
                                                                    nil,
                                                                    kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                    &buffer)
            
            let abl = UnsafeMutableAudioBufferListPointer(&audioBufferList)
            var maxAmplitude : Int16 = 0
            
            for buffer in abl {
                let samples = UnsafeMutableBufferPointer<Int16>(start: UnsafeMutablePointer(buffer.mData), count: Int(buffer.mDataByteSize) / sizeof(Int16))
                
                for sample in samples {
                    sampleSkipCounter += 1
                    maxAmplitude = max(maxAmplitude, sample)
                    
                    if sampleSkipCounter == stride {
                        sampleData.append(Float(scalar(maxAmplitude)))
                        sampleSkipCounter = 0
                        maxAmplitude = 0
                    }
                }
            }
            CMSampleBufferInvalidate(sampleBuffer)
        }
    }
    
    return sampleData
}
