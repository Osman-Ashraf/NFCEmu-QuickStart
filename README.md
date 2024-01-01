<p align="center">
  <a href="" rel="noopener">
 <img width=200px height=200px src="artwork/nfcemul.png" alt="Project logo"></a>
</p>

<h3 align="center">NFCEmu-QuickStart</h3>

<h2 align="center"> 
	
[![Status](https://img.shields.io/badge/status-active-success.svg)]()
</h2>


<p align="center"> NFC Terminal Quick Setup
    <br> 
</p>

## 📝 Table of Contents

- [About](#about)
- [Getting Started](#getting_started)
- [Prerequisites](#deployment)
- [Installation and Config](#Installation_and_Config)
- [Test](#test)
- [Built Using](#built_using)
- [Authors](#authors)
- [Contributors](#contributors)

## 🧐 About <a name = "about"></a>

This repository contains the installer setup for quick setup of NFC Terminal app.

## 🏁 Getting Started <a name = "getting_started"></a>

These instructions will get you a copy of the project up and running on your Raspberry Pi/local machine for development and testing purposes. See [deployment](#deployment) for notes on how to deploy the project on a live system.

### Prerequisites <a name = "Prerequisites"></a>

What things you need to install the software and how to install them.

```
- Raspberry Pi Model 3B, 3B+, 4B or CM4 (with Internet Connection)
- Github Personal Access Token
```

- Get a [GitHub Personal Access Token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/)


## Installation and Update <a name = "Installation_and_Config"></a>

- Once you have the GitHub Personal Access Token execute the following command on the terminal

```bash
export TOKEN=[REPLACE_WITH_GITHUB_PERSONAL_ACCESS_TOKEN]
```

You will need to run the following command in order to install or update the NFCEmu
```bash
wget -O -  https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/main/installer.sh | bash
```
## ⛏️ Running <a name = "test"></a>

1.  The program can be run using the following command
```bash
cd ~/NFCEmu
./run.sh
```

## ⛏️ Built Using <a name = "built_using"></a>

- [Python3](https://www.python.org/) - Raspberry Pi Firmware
- Bash

## ✍️ Authors <a name = "authors"></a>

- [@Nauman3S](https://github.com/Nauman3S) - Development and Deployment

## 🤝 Contributors <a name = "contributors"></a>

- [@ali-yasir-binairy](https://github.com/ali-yasir-binairy) 
