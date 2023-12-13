// 数据绑定，根据情况自行修改
const Code = "Attribute";
const StorageKey = "selectedDeviceId";

let contextObj = this.contextObj,
  widget = this,
  selectedDeviceId = localStorage.getItem(StorageKey) || null,
  html5QrCode;

document.body.classList.add("claro");
mxui.dom.addCss("mxclientsystem/dijit/themes/claro/claro.css");

async function main() {
  const [dom, domConstruct, Button, aspect] = await injectDeps([
    "dojo/dom",
    "dojo/dom-construct",
    "dijit/form/Button",
    "dojo/aspect",
  ]);

  aspect.after(widget, "update", function () {
    contextObj = widget.contextObj;
  });

  widget.addOnLoad(async function () {
    const devices = await Html5Qrcode.getCameras();
    await renderDojoSelect(devices);

    // 创建扫码按钮
    var scanButton = new Button({
      label: "扫码",
      resize: function () {},
      onClick: async function () {
        await startScanning(selectedDeviceId);
      },
    });

    var targetDiv = dom.byId(widget.id);
    domConstruct.place(scanButton.domNode, targetDiv);

    widget.addOnDestroy(function () {
      html5QrcodeScanner?.clear();
    });
  }); // end addOnLoad
}
main();

async function injectDeps(deps) {
  return await new Promise((resolve) => {
    if (!Array.isArray(deps)) {
      deps = [deps];
    }
    window.dojoDynamicRequire(deps, function () {
      resolve(Array.from(arguments));
    });
  });
}

async function startScanning(deviceId) {
  const [Dialog, Select, Button] = await injectDeps([
    "dijit/Dialog",
    "dijit/form/Select",
    "dijit/form/Button",
  ]);

  // 创建全屏弱弹窗
  var dialog = new Dialog({
    title: "扫码弹窗",
    style: "width: 100%; height: 100%;",
  });
  // 生成唯一的ID
  var uniqueId = dijit.registry.getUniqueId("helloWorldDiv");
  domConstruct.create(
    "div",
    {
      id: uniqueId,
    },
    dialog.containerNode
  );

  // 监听点击弹窗背景的事件
  dialog.onCancel = async function () {
    // 关闭弹窗
    await html5QrCode?.stop();
    html5QrCode?.clear();
    html5QrCode = null;
    dialog.destroy();
  };
  // 显示弹窗
  dialog.show();

  // 计算合适的 QR Code 尺寸
  var qrboxSize = Math.min(document.body.clientWidth * 0.8, 300); // 80% of the smaller dimension

  html5QrCode = new Html5Qrcode(/* element id */ uniqueId);
  html5QrCode
    .start(
      deviceId,
      {
        fps: 10,
        qrbox: qrboxSize,
        useBarCodeDetectorIfSupported: true,
        rememberLastUsedCamera: true,
        videoConstraints: { facingMode: "environment" },
      },
      onScanSuccess,
      (errorMessage) => {
        // parse error, ignore it.
      }
    )
    .catch((err) => {
      // Start failed, handle it.
    });

  async function onScanSuccess(decodedText, decodedResult) {
    console.info(`Scan result ${decodedText}`, decodedResult);
    widget.contextObj?.set(Code, decodedText);

    mx.data.callNanoflow({
      nanoflow: widget.onclicknf,
      context: widget.mxcontext,
    });
    await html5QrCode?.stop();
    html5QrCode?.clear();
    html5QrCode = null;
    dialog.destroy();
  } //end OnScanSuccess
} //end startScanning

//更新存储
function onSelectDevice(deviceId) {
  selectedDeviceId = deviceId;
  localStorage.setItem(StorageKey, selectedDeviceId);
}
async function renderDojoSelect(devices) {
  const [Dialog, Select, Button] = await injectDeps([
    "dijit/Dialog",
    "dijit/form/Select",
    "dijit/form/Button",
  ]);
  /**
   * devices would be an array of objects of type:
   * { id: "id", label: "label" }
   */
  if (devices && devices.length) {
    const deviceSelect = new Select({
      name: "deviceSelect",
      resize: function () {},
      options: devices.map((device) => ({
        label: device.label,
        value: device.id,
      })),
      value: selectedDeviceId,
      onChange: function (newDeviceId) {
        onSelectDevice(newDeviceId); // 更新存储
        // 其他相关操作，例如启动扫描等
        startScanning(newDeviceId);
      },
    });

    deviceSelect.placeAt(widget.id);

    // 如果用户之前已经选择了设备，使用该设备
    if (selectedDeviceId) {
      const selectedDevice = devices.find(
        (device) => device.id === selectedDeviceId
      );
      if (selectedDevice) {
        deviceSelect.set("value", selectedDevice.id);
      } else {
        // 如果存储的设备在当前列表中不存在，选择第一个设备作为默认
        deviceSelect.set("value", devices[0].id);
        onSelectDevice(devices[0].id); // 更新存储
      }
    } else {
      // 如果用户没有之前的选择，选择第一个设备作为默认
      deviceSelect.set("value", devices[0].id);
      onSelectDevice(devices[0].id); // 更新存储
    }
  }
}
