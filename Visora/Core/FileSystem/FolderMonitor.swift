import Foundation

/// 监听指定目录的文件系统变化（新增、删除、重命名等），并在去抖后回调主线程刷新图片序列
final class FolderMonitor {
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "visora.folder.monitor", qos: .utility)
    private(set) var monitoredURL: URL?

    deinit {
        stop()
    }

    func startMonitoring(folderURL: URL, onChange: @escaping () -> Void) {
        if monitoredURL == folderURL, source != nil {
            return
        }
        stop()

        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        fileDescriptor = fd
        monitoredURL = folderURL

        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: queue
        )

        dispatchSource.setEventHandler { [weak self] in
            guard let self else { return }
            self.debounceWorkItem?.cancel()
            let item = DispatchWorkItem {
                DispatchQueue.main.async {
                    onChange()
                }
            }
            self.debounceWorkItem = item
            self.queue.asyncAfter(deadline: .now() + 0.25, execute: item)
        }

        dispatchSource.setCancelHandler {
            close(fd)
        }

        source = dispatchSource
        dispatchSource.resume()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
        fileDescriptor = -1
        monitoredURL = nil
    }
}
