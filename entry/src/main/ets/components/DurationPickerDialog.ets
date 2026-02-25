// DurationPickerDialog.ets
interface GeneratedTypeLiteralInterface_1 {
  selected?: number; // 默认选中的时长（秒）
  onAccept?: (value: number) => void;
  onCancel?: () => void;
  minDuration?: number;
  maxDuration?: number;
}

export class DurationPickerDialog {
  static show(options: GeneratedTypeLiteralInterface_1, ctx: UIContext) {
    let selected = options.selected || 0;
    let onAccept = options.onAccept;
    let onCancel = options.onCancel;
    let min = options.minDuration || 0;
    let max = options.maxDuration || Infinity;

    // 将总秒数转换为时、分、秒
    const hours = Math.floor(selected / 3600);
    const minutes = Math.floor((selected % 3600) / 60);
    const seconds = selected % 60;

    // 生成时、分、秒的选择范围
    const hourRange = Array.from<number, string>({ length: 24 }, (_, i) => `${i}时`);
    const minuteRange = Array.from<number, string>({ length: 60 }, (_, i) => `${i}分`);
    const secondRange = Array.from<number, string>({ length: 60 }, (_, i) => `${i}秒`);

    // 显示多列 TextPickerDialog
    ctx.showTextPickerDialog({
      canLoop: true,
      range: [hourRange, minuteRange, secondRange],
      selected: [hours, minutes, seconds],
      onAccept: (value: TextPickerResult ) => {
        if (onAccept) {
          const h: number = value.index[0] || 0;
          const m: number = value.index[1] || 0;
          const s: number = value.index[2] || 0;
          const duration = h * 3600 + m * 60 + s;
          try {
            if (duration < min) {
              ctx.getPromptAction().showToast({
                message: '选择的时长过短',
                duration: 2000
              })
            }
            else if (duration > max) {
              ctx.getPromptAction().showToast({
                message: '选择的时长过长',
                duration: 2000
              })
            }
            else {
              ctx.getPromptAction().showToast({
                message: '设置成功',
                duration: 2000
              })
              onAccept(duration);
            }
          }
          catch (e) {

          }
        }
      },
      onCancel: onCancel
    });
  }
}