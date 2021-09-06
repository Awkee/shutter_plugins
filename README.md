# shutter_plugins
一些免费的shutter插件，图片上传插件以及一些图片处理脚本

## 上传插件

### SM.MS上传插件

使用方式有两种：
1. 匿名上传： 没有说明限制，但可能会被删除。
2. 使用注册用户API上传： 合理管理自己的图片素材。

因此，我们还是使用注册用户API上传，其实也很简单。

1. 注册并获取一个sm.ms帐号。
2. 在用户面板(Dashboard)中找到自己的`api-token`。
3. 最后，在自己的系统里创建一个配置文件 `$HOME/.smms-api-config`，内容如下。
```json
{
  "api_token" : "你的api-token"
}
```
保存配置文件后，重新启动一下`shutter`截图软件就可以使用了。

> 使用方法： 选中一个图片 -> 点击右上角的`导出` -> 选择`公共主机`中的`SMMS客户端` --> 点击`上传`。

上传完成后，会显示返回的链接地址信息， 我们可以直接使用这些链接信息编写文章了。


### Imgur上传插件

使用方式有两种：
1. 匿名上传： 没有说明限制，但可能会被删除。只能通过上传时返回的删除链接来删除图片。
2. 使用注册用户授权OAuth方式上传： 合理管理自己的图片素材。

同样，我们介绍下用注册用户API上传的主要流程：

1. 注册并获取一个`Imgur`帐号。
2. 注册完毕后，点击链接访问[添加oauth2客户端API地址](https://api.imgur.com/oauth2/addclient)，`callback地址`填写"https://oauth.pstmn.io/v1/browser-callback",填写完毕点击`submit`提交。
3. 提交成功后，会返回`client-id`和`client-secret`两个密钥信息，保存好，关闭这个页面后`client-secret`就不见了，如果没保存，只能通过重新生成方式获取一个新的`client-secret`了。
4. 为了获取`access_token`，我们会用到`Postman`，先 [注册Postman帐号](https://identity.getpostman.com/signup) 或者使用`Google帐号`登录也是可以的。
5. 注册登录成功后，点击`Create new`--选择->新建`Collection`，起个名字 "Imgur"。
6. 设置`Authoriztion` , `Type`：`OAuth 2.0` , `Token Name`: `Imgur`， `Callback URL`是在添加`Imgur OAuth2.0客户端`时填写的， `Auth URL`： `https://api.imgur.com/oauth2/authorize` ， `Access Token URL` ： `https://api.imgur.com/oauth2/token` ，`Client ID` 和 `Client Secret`填写刚才获得的。
7. 点击`Get New Access Token`按钮提交前，还要安装本地客户端代理PostmanAgent,启动`PostmanAgent`后，再浏览器的右下角选择`Desktop Agent`，现在可以点击`Get New Access Token`按钮提交啦。
8. 成功后，我们就可以看到弹出窗口中展示了`access_token`和`refresh_token` 这两个重要的`token`，`access_token`是要填写到配置文件中使用的，`refresh_token`是用于重新生成`access_token`用的。
9. 最后，在自己的系统里创建一个配置文件 `$HOME/.imgur-api-config`，内容如下。
```json
{
  "access_token": "你的access_tooken",
  "refresh_token": "你的refresh_token",
  "client_id": "注册APP时的客户端ID",
  "client_secret": "注册APP时的客户端Secret"
}
```

步骤看着较多，按说明一步步操作下来其实很快，最终的目的就是为了获得`access_token`和`refresh_token`。

- access_token: 是您用于访问用户数据的密钥。可以认为是用户的密码和用户名合二为一，用于访问用户的帐号。它在 1 个月后到期。
- refresh_token: 用于请求新的 access_tokens 。由于 access_tokens 在 1 个月后过期，我们需要一种无需再次通过整个授权步骤即可请求新令牌的方法。它不会过期。


保存配置文件后，重新启动一下`shutter`截图软件就可以使用了。

> 使用方法： 选中一个图片 -> 点击右上角的`导出` -> 选择`公共主机`中的`Imgur客户端` --> 点击`上传`。

> 可能你在`公共主机`中看到了`Imgur OAuth`选项，这个功能增加了更新`access_token`功能，可以在`access_token`失效时使用这个选项上传一次，它就会生成新的`access_token`并保存到了`$HOME/.imgur-api-config`文件中。

上传完成后，会显示返回的链接地址信息， 我们可以直接使用这些链接信息编写文章了。

- 添加oauth2客户端API地址：
![添加oauth2客户端API地址](https://i.imgur.com/vpLB8py.png)

- Postman设置页面
![> Postman设置页面](https://i.imgur.com/GgVrkZY.png)

> 更详细的设置过程参见 [注册应用程序过程介绍](https://apidocs.imgur.com/#intro) 。

---
