@Component
export struct InspirationPage {
  build() {
    Column() {
      Text('灵感视图')
        .fontSize(24)
        .fontColor('#333333')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    // .backgroundColor('#F5F5F5')
  }
}