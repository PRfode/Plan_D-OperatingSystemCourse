// FabButton.ets
@Component
export struct FabButton {
  @Prop icon: Resource;
  onTap: () => void = () => {};

  build() {
    Column() {
      Stack() {
        Circle()
          .width(56)
          .height(56)
          .fill('#007DFF')
          .borderRadius(28)
          .shadow({
            radius: 16,
            color: '#77000000',
            offsetX: 0,
            offsetY: 0
          })

        Image(this.icon)
          .width(36)
          .height(36)
          .fillColor(Color.White)
      }
      .onClick(this.onTap)
    }
    .hitTestBehavior(HitTestMode.Transparent)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 24 })
  }
}