<div align="center">

# 🕧 TickTerm ⏰
〰〰〰〰〰〰〰〰〰〰〰


A *fluid*, **customizable** clock app in the terminal

</div>

## Showcase 💖

<div align="center">

| Clock Animation | Underline Effect |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/af703127-d0fb-43ea-9015-6951e3009a3a" width="400" /> | <img src="https://github.com/user-attachments/assets/758e2eae-c9c5-498d-8e49-2a044d619f7c" width="400" /> |
  
| Responsive Layout | Zen Mode |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/3077e19c-bf34-4af6-9f8c-289cd0630e2c" width="400" /> | <img src="https://github.com/user-attachments/assets/170f5b1e-a474-4e6d-86c9-797725a6cfd8" width="400" /> |
</div>

## Cool Stuff 🤩
- **Underline** clock tick indicates the **SS** format 🕧
- *Responsive* layout for any terminal **size**
- **Zen** mode, best for work focusing 🎯 or *aesthetic*
- *Customizable* ASCII number style 🔢 with:
   - `.flf` files
- Highly configurable:
   - default options 🎛
   - colors 🌈
   - date & time format 📅
   - underline character style 🕰️
 
## Install
### Installation from source
Requirements:
  - [nim](https://nim-lang.org/) programming langauge
  - gcc and it's dependencies

#### Build from source

1. clone `tickterm` repository
```yaml
git clone https://github.com/waxodium/tickterm.git
```

2. Use Makefile to install
```bash
cd tickterm
make install
```

## Sample Usage
To get help, run:
```bash
tickterm --help
```

- Underline:
```bash
tickterm --underline
```

- Zen Mode:
```bash
tickterm --zen
```

- Change the clock's **ASCII number** style:
```bash
# Built-in font
tickterm --font rammstein

# Custom FIGlet font
tickterm --font ./font.flf
```

## LICENSE
TickTerm is licensed under the [Apache License 2.0](./LICENSE). See the LICENSE file for full detail: [LICENSE](./LICENSE);

