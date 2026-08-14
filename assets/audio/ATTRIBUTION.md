# 《筑风》外部音频授权记录

> 来源包：Sonniss #GameAudioGDC Bundle Part 9（GDC 2026 Game Audio Bundle）
> 授权：ROYALTY-FREE，个人与商业使用均可，无需署名；具体条款以各包内 `License - GDC Game Audio.pdf` 为准
> 另有：Boom Library Casual UI（3745 个休闲游戏 UI 音效素材包），许可见包内 `00_BOOM-Library-EULA-2022.pdf`
> 官方来源：https://sonniss.com
> 下载日期：2026-08-12
> 修改情况：仅重命名；未进行剪辑、变速、混音或格式转换

| 资产 ID / 最终文件名 | 作者或版权方 | 原始文件路径 |
|---|---|---|
| AUD-002_UI选择确认_01.wav | Epic Stock Media | Bundle2of5\Epic Stock Media - Board Game - Sound Set Kit for Tabletop and Digital Games\UIClick_UI Button Analog Vintage Double Click Neutral Dry Press 11_ESM_BG.wav |
| AUD-002_UI选择确认_02.wav | InMotionAudio | Bundle3of5\InMotionAudio - USA Hotel\MECHClik_USALightSwitch_On05_InMotionAudio_USAHotel.wav |
| AUD-003_装置放置_合法.wav | Epic Stock Media | Bundle2of5\Epic Stock Media - HD Lock And Mechanism Sound Design Kit\MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav |
| AUD-003_装置放置_非法.wav | Boom Library | 3745个休闲游戏UI交互点击移动碰撞无损音效素材 Boom Library Casual UI\Boom_Library_Casual_UI_DS\UIMisc_DENY-No_B00M_CUDS.wav |
| AUD-004_装置旋转_01_电话拨盘.wav | 344 Audio | Bundle1of5\344 Audio - Antique Telephone\COMTelph_Antique Telephone Rotary Dial Number  9_344 Audio_Antiques - Telephone.wav |
| AUD-005_删除退款.wav | Boom Library | 3745个休闲游戏UI交互点击移动碰撞无损音效素材 Boom Library Casual UI\Boom_Library_Casual_UI_CK\OBJCoin_COIN-Single Drop On Table_B00M_CUCK.wav |
| AUD-006_风流循环.wav | Epic Stock Media | Bundle2of5\Epic Stock Media - Strange Game Ambient Loops 3\AMBRoom_Factory Loop Heavy Machinery Tonal Roomtone Dark Wind Vent_ESM_SGA3.wav |
| AUD-007_涡轮启动.wav | 344 Audio | Bundle1of5\344 Audio - Barbershop Vol. 1\OBJMisc_Hair Dryer, On, Idle, Off 4_344 Audio_Barbershop Vol 1.wav |
| AUD-007_门开启.wav | 344 Audio | Bundle1of5\344 Audio - Climbing Gear Foley Vol. 1\EQUISprt_Climbing Gear, Carabiner, Screwing Lock 01_344 Audio_Climbing Gear Foley Vol 1.wav |
| AUD-008_失败_坠落.wav | 344 Audio | Bundle1of5\344 Audio - Bass Drops & Downers Vol. 1\DSGNBass_Bass Drop & Downer Fast 16_344 Audio_Bass Drops & Downers.wav |
| AUD-008_失败_碰撞_金属重击.wav | The Noisery | Bundle5of5\The Noisery - Moaning Metal\DSGNImpt_Metal Hit Thud Thump Low Ring Geofon 1_The Noisery_Moaning Metal.wav |
| AUD-008_失败_停滞.wav | Boom Library | 3745个休闲游戏UI交互点击移动碰撞无损音效素材 Boom Library Casual UI\Boom_Library_Casual_UI_CK\UIClick_CLICK WOOD-Block Hit Small_B00M_CUCK.wav |
| AUD-009_通关_普通.wav | Cinematic Sound Design | Bundle2of5\Cinematic Sound Design - UI Interaction Elements\Ting Coins.wav |
| AUD-009_通关_精简_音乐盒B.wav | Sonic Bat | Bundle4of5\Sonic Bat - Music Boxes\SBmb_Music Box B 028.wav |
| AUD-010_尾声_素材_连胜.wav | Boom Library | 3745个休闲游戏UI交互点击移动碰撞无损音效素材 Boom Library Casual UI\Boom_Library_Casual_UI_DS\UIMvmt_WHOOSH POSITIVE-Winning Streak_B00M_CUDS.wav |

> 上述原始路径均省略 `D:\游戏音效\` 前缀。进入候选构建前，请按本表核对作者、来源、许可证与修改记录。

## 引擎导入补充记录（2026-08-14）

- 本项目的资产来自 `C:\Users\flow032417\Pictures\CC asset`，外部来源文件未被修改。
- `AUD-009_通关_普通.wav` 的项目副本因 WAVE_FORMAT_EXTENSIBLE 与 Godot 4.6 不兼容，已等价标准化为 IEEE float WAV；其余音频副本保持原始编码。
- 全部 WAV 的 Godot 导入缓存限制为最高 48 kHz，并使用引擎默认 QOA 压缩模式；这只影响生成的导入缓存。
