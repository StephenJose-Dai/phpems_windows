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
