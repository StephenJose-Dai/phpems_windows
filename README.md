**在部署phpems之前，你需要先安装docker和docker compose，Docker Desktop For Windows在 https://www.docker.com/ 首页可以下载**

**[也可以点击这里直接下载](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe?utm_source=docker&utm_medium=webreferral&utm_campaign=dd-smartbutton&utm_location=module)**

<img width="2317" height="1452" alt="QQ_1772262550187" src="https://github.com/user-attachments/assets/ad51c67f-d2cf-40c8-8270-7f09ce4e16b2" />


**安装docker的话，通常docker compose都会一并安装掉**
**docker安装完成后再来执行下列操作**

**目前支持 `在线` 和 `离线` 来部署phpems docker版，但仅支持 `Windows10` 和 `Windows11`，请根据具体情况和需求来选择**



### 一、在线安装
#### 1、到 https://github.com/StephenJose-Dai/phpems_windows/releases 下载最新的 ```phpems_win_install.bat``` 或者 ```phpems_win_install.ps1``` 文件

##### 2.1、如果你下载的是bat的安装脚本，那需要以管理员的身份打开CMD，然后将脚本拉到cmd窗口里或者复制脚本的路径到cmd窗口里，接着回车，等待检测完毕后，会询问你要选择在线pull还是离线包导入，选择1，最后按照窗口提示一步一步执行即可

##### 2.2、如果你下载的是sp1的安装脚本，那需要以管理员的身份打开 **powershell**，然后将输入
```
powershell -ExecutionPolicy Bypass -File phpems_win_install.sp1
```
（比如你的脚本在D盘的script目录下，那命令就是
```
powershell -ExecutionPolicy Bypass -File D:\script\phpems_win_install.sp1
```
），接着回车，等待检测完毕后，会询问你要选择在线pull还是离线包导入，选择1，最后按照窗口提示一步一步执行即可。

#### 3、安装完毕后，窗口会显示访问地址、用户名密码等信息，该信息仅显示一次，记得妥善保存。


### 二、离线安装

#### 1、到 https://github.com/StephenJose-Dai/phpems_windows/releases 下载最新的 ```phpems_win_install.bat``` 或者 ```phpems_win_install.ps1``` 文件和 ```phpems_windows_11.tar.gz```

#### 2、解压 ```phpems_windows_11.tar.gz```

#### 3.1、如果你下载的是bat的安装脚本，那需要以管理员的身份打开CMD，然后将脚本拉到cmd窗口里或者复制脚本的路径到cmd窗口里，接着回车，等待检测完毕后，会询问你要选择在线pull还是离线包导入，选择 **2** ，输入解压后的镜像路径，最后按照窗口提示一步一步执行即可，这里路径只需要相对路径就行，不需要绝对路径，比如解压后你的镜像在 
```
D:\dockerimg\phpems_windows_11.tar
```
，那你只需要输入
```
D:\dockerimg
```

#### 3.2、如果你下载的是sp1的安装脚本，那需要以管理员的身份打开powershell，然后将输入

```
powershell -ExecutionPolicy Bypass -File phpems_win_install.sp1
```
（比如你的脚本在D盘的script目录下，那命令就是
```
powershell -ExecutionPolicy Bypass -File D:\script\phpems_win_install.sp1
```
），接着回车，等待检测完毕后，会询问你要选择在线pull还是离线包导入，选择2，最后按照窗口提示一步一步执行即可，这里路径只需要相对路径就行，不需要绝对路径，比如解压后你的镜像在
```
D:\dockerimg\phpems_windows_11.tar
```
，那你只需要输入
```
D:\dockerimg
```
#### 4、安装完毕后，窗口会显示访问地址、用户名密码等信息，该信息仅显示一次，记得妥善保存。


# 支援
如果有部署问题或者其他问题，可以联系作者支援  

![戴戴的Linux](qrcode.jpg)  ![phpems技术交流群](qqqrc.jpg)  
