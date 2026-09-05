#!/bin/bash
# ================== 颜色定义 ==================
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"
BOLD="\033[1m"
ORANGE='\033[38;5;208m'


# ================== GitHub 代理列表 ==================
# 第一个留空代表默认直连
GITHUB_PROXY=(
    '' 
    'https://v6.gh-proxy.org/'
    'https://ghfast.top/'
    'https://gh-proxy.com/'
    'https://hub.glowp.xyz/'
    'https://proxy.vvvv.ee/'
    'https://ghproxy.lvedong.eu.org/'
)

# ================== 轮询检测网络 ==================
CHOSEN_PROXY=""

for proxy in "${GITHUB_PROXY[@]}"; do
    if [ -z "$proxy" ]; then

        # 测试直连，5秒超时
        if curl -o /dev/null -s -m 5 "https://raw.githubusercontent.com"; then
            CHOSEN_PROXY=""
            break
        fi
    else
        # 测试代理站是否可用
        if curl -o /dev/null -s -m 2 "${proxy}https://raw.githubusercontent.com"; then
            CHOSEN_PROXY="$proxy"
            break
        fi
    fi
done


# ================== 脚本路径 ==================
SCRIPT_PATH="/etc/store.sh"
SCRIPT_URL="https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Store.sh"
BIN_LINK_DIR="/usr/local/bin"


# ================== 首次运行自动安装 ==================
if [ ! -f "$SCRIPT_PATH" ]; then
    mkdir -p "$(dirname "$SCRIPT_PATH")"
    
    REAL_URL="${CHOSEN_PROXY}${SCRIPT_URL}"
    
    curl -fsSL -o "$SCRIPT_PATH" "$REAL_URL"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 安装失败，请检查网络或 URL${RESET}"
        exit 1
    fi
    chmod +x "$SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/d"
    ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/D"
    echo -e "${GREEN}✅ 安装完成${RESET}"
    echo -e "${GREEN}✅ 快捷键已添加：d 或 D 可快速启动${RESET}"
fi

# ================== 一级菜单分类 ==================
declare -A categories=(
    [1]="Docker管理"
    [2]="数据证书"
    [3]="订阅转换"
    [4]="监控通知"
    [5]="网络工具"
    [6]="媒体服务"
    [7]="面板项目"
    [8]="实用工具"
    [9]="交易商店"
    [10]="文件管理"
    [11]="机器人项目"
    [12]="游戏项目"
    [13]="甲骨文云服务"
    [14]="IDC服务"
    [15]="AI项目"
)

# ================== 二级菜单应用 ==================
declare -A apps=(
    [1,1]="Docker        安装管理"
    [1,2]="Dockercompose 项目管理"
    [1,3]="Dockercompose 备份恢复"
    [1,4]="Dockercompose 自动更新"
    [1,5]="Dockercompose TGBot"
    [2,1]="MySQL      数据管理"
    [2,2]="PostgreSQL 数据管理"
    [2,3]="Redis      数据管理"
    [2,4]="MongoDB    数据管理"
    [2,5]="MariaDB    数据管理"
    [2,6]="DBX        数据管理"
    [2,7]="Lucky      反向代理"
    [2,8]="NGINXV4    反向代理"
    [2,9]="NGINXV6    反向代理"
    [2,10]="Caddy      反向代理"
    [2,11]="Acme       证书申请"
    [3,1]="Wallos        财务管理"
    [3,2]="Renewlet      财务管理"
    [3,3]="SubTracker    财务管理"
    [3,4]="EasySub       财务管理"
    [3,5]="Vaultwarden   密码管理"
    [3,6]="2FAuth        2FA验证器"
    [3,7]="PocketID      OIDC认证"
    [3,8]="Tinyauth      身份验证"
    [3,9]="subs-check    节点管理"
    [3,10]="miaomiaowu    节点管理"
    [3,11]="Sub-store     节点管理"
    [3,12]="SubBoost      节点管理"
    [3,13]="TOTP2FA       2FA验证码共享看板"
    [3,14]="PrivateRules  分流规则管理工具"
    [4,1]="Uptime-kuma      监控"
    [4,2]="Kuma-Mieru       监控"
    [4,3]="Komari           监控"
    [4,4]="哪吒V1           监控"
    [4,5]="Beszel           监控"
    [4,6]="NodeGet          监控"
    [4,7]="Apprise          通知"
    [4,8]="wxchat           微信转发代理"
    [4,9]="CloudEye         监控面板"
    [4,10]="komaritraffichub TGBot"
    [4,11]="ktui             komariTUI"
    [4,12]="Lite             监控"
    [5,1]="彩虹聚合DNS  DNS管理"
    [5,2]="DDNS-GO      DNS管理"
    [5,3]="AdguardHome  DNSDoH"
    [5,4]="OpenFlare    CDN加速"
    [5,5]="FlareSolverr 绕过Cloudflare反爬虫保护"
    [5,6]="雷池WAF      网络防御"
    [5,7]="SamWaf       网络防御"
    [5,8]="GHProxy      代理加速"
    [5,9]="Hubroxy      代理加速"
    [5,10]="Apple        Apple网络定位修改"
    [5,11]="CFTun-UI     CloudflareTunnel管理面板"
    [5,12]="Mantou       网络工具面板"
    [6,1]="AList-TvBox     小雅AList"
    [6,2]="小雅全家桶      小雅Emby"
    [6,3]="Emby官方版      多媒体管理系统"
    [6,4]="Emby开心版      多媒体管理系统"
    [6,5]="Jellyfiny       多媒体管理系统 "
    [6,6]="MediaStationGo  媒体库自动化管理工具"
    [6,7]="MoviePilot      媒体库自动化管理工具"
    [6,8]="kaloscope       追番媒体库管理工具"
    [6,9]="Audiobookshelf  有声书播客管理工具"
    [6,10]="Audiobookshelf  喜马拉雅元数据刮削"
    [6,11]="Navidrome       音乐管理系统"
    [6,12]="musictagweb     音乐刮削"
    [6,13]="TuneScout       音乐库管理管理工具"
    [6,14]="LrcApi          歌词API"
    [6,15]="LogVar          弹幕API"
    [6,16]="metatube        AV刮削"
    [6,17]="MDC-NG          AV刮削"
    [6,18]="MHTI            里番刮削"
    [6,19]="AutoBangumi     全自动追番"
    [6,20]="ANI-RSS         全自动追番"
    [6,21]="emby-pulse      Emby服务管理"
    [6,22]="EmbyTGBot       Emby服务管理"
    [6,23]="Kavita          漫画管理"
    [6,24]="Suwayomi        漫画阅读器"
    [6,25]="Komga           图书管理"
    [6,26]="koodoreader     图书阅读器"
    [6,27]="TgtoDrive       网盘媒体自动化管理工具"
    [6,28]="MediaryScout    网盘媒体自动化管理工具"
    [6,29]="PanSou          网盘搜索"
    [6,30]="magnetfix       磁力搜索"
    [6,31]="91影视          个人私有视频站"
    [6,32]="DecoTV          影视网站"
    [6,33]="Lxserver        网页音乐播放器"
    [6,34]="IPTVTRMAS       IPTV直播管理"
    [6,35]="Emby-In-OneEmby Emby服务器聚合"
    [6,36]="Emby-proxy-go   Emby反代通用"
    [6,37]="EmbyProxy       Emby反代面板"
    [6,38]="Vertex          PT刷流管理工具"
    [6,39]="IYUU            自动辅种工具"
    [6,40]="ReClip          视频音频下载器"
    [6,41]="BiliLive-Tools  直播录制"
    [6,42]="Transmission    BT下载工具"
    [6,43]="qBittorrent     二进制"
    [6,44]="qBittorrent     系统包"
    [6,45]="qBittorrent     Docker"
    [6,46]="qBit-Bot        TGBot"
    [6,47]="Aria2           Docker"
    [6,48]="GlobalRadio     全球电台"
    [6,49]="Kerkerker       影视网站"
    [6,50]="Kikoeru         ASMR助眠"
    [6,51]="ReadCLI         终端阅读器"
    [6,52]="BitPlay         在线播放磁力"
    [6,53]="AegisRelay      Emby反代面板"
    [6,54]="Animaku         在线追番"
    [6,55]="metube          油管视频下载"
    [6,56]="nowen-video     媒体库自动化管理工具"
    [6,57]="OnePick         多平台媒体解析下载"
    [6,58]="Live-Event      IPTV体育赛事直播"
    [6,59]="Meridian        Emby反代面板"
    [6,60]="FluxDown        多协议下载管理器"
    [6,61]="DownloadManager 多协议下载管理器"
    [6,62]="MeBox           媒体库自动化管理工具"
    [7,1]="WordPress        博客工具"
    [7,2]="Halo             博客工具"
    [7,3]="Typecho          博客工具"
    [7,4]="Flarum           论坛软件"
    [7,5]="Rhex             论坛软件"
    [7,6]="XIAOJUSURVEY     问卷系统"
    [7,7]="Twikoo           评论系统"
    [7,8]="Artalk           评论系统"
    [7,9]="Umami            网站统计"
    [7,10]="Moe-Counter      网站计数"
    [7,11]="RemioHome        个人主页"
    [7,12]="Moments          微信朋友圈"
    [7,13]="MomentsBlog      微信朋友圈"
    [7,14]="PandaWiki        文档工具"
    [7,15]="宝塔面板         国际版"
    [7,16]="宝塔面板         开心版"
    [7,17]="1Panel V1        开心版"
    [7,18]="1Panel V2        开心版"
    [7,19]="KaraKeep         书签管理"
    [7,20]="Sun-Panel        导航面板"
    [7,21]="FlatNas          导航面板"
    [7,22]="青龙面板         定时任务"
    [7,23]="白虎面板         定时任务"
    [7,24]="朱雀面板         定时任务"
    [7,25]="呆呆面板         定时任务"
    [7,26]="蜘蛛网络         Cloudflare管理"
    [7,27]="HTML             网站部署"
    [7,28]="bbs1org          轻量级论坛"
    [8,1]="Windows          DockerWin"
    [8,2]="Firefox          Docker浏览器"
    [8,3]="Chrom            Docker浏览器"
    [8,4]="SearXNG          聚合搜索"
    [8,5]="Zurl             短链接系统"
    [8,6]="ForgejoGit       Gitea"
    [8,7]="LiteGist         Gist"
    [8,8]="MagicResume      简历模板"
    [8,9]="Translate        翻译工具"
    [8,10]="Utils.fun        工具箱"
    [8,11]="VoceChat         聊天系统"
    [8,12]="Paperphoneplus   聊天系统"
    [8,13]="Poste.io         邮件服务"
    [8,14]="OutlookEmailPlus 邮箱管理"
    [8,15]="MailGo           邮箱管理"
    [8,16]="Backrest         备份管理"
    [8,17]="VaultFleet       备份管理"
    [8,18]="SiYuan           思源笔记"
    [8,19]="Ech0             博客笔记"
    [8,20]="ZNote            笔记"
    [8,21]="CookieCloud      Cookie同步工具"
    [8,22]="WebSSH           网页版SSH"
    [8,23]="ShadowSSH        网页版SSH" 
    [8,24]="Quick-SSH        终端SSH"
    [8,25]="DockUP           Docker更新通知"
    [8,26]="Watchtower       Docker自动更新"
    [8,27]="ComposeTool      DockerCompose配置转换工具"
    [8,28]="OutlookMailVoxi  微软邮箱管理"
    [8,29]="OutlookMailHub   微软邮箱管理"
    [9,1]="独角数卡        发卡系统"
    [9,2]="异次元商城      发卡系统"
    [9,3]="萌次元商城      发卡系统"
    [9,4]="Fakabot         发卡机器人"
    [9,5]="BEpusdt         交易系统"
    [9,6]="UPAYPRO         交易系统"
    [9,7]="Epusdt          交易系统"
    [9,8]="EpayBot         订单通知"
    [10,1]="Cloudreve      云盘管理"
    [10,2]="FileBrowser    云盘管理"
    [10,3]="OpenList       云盘管理"
    [10,4]="WebDAV         文件管理"
    [10,5]="兰空图床       图床项目"
    [10,6]="图片API        兰空图床"
    [10,7]="简单图床       图床项目"
    [10,8]="EasyImg        图床项目"
    [10,9]="初春图床       图床项目"
    [10,10]="IMGAPI         图片API"
    [10,11]="ConvertX       文件转换"
    [10,12]="Enclosed       阅后即焚"
    [10,13]="FileTransferGo 文件分享"
    [10,14]="FileCodeBox    文件分享"
    [10,15]="send           文件分享"
    [10,16]="015            文件分享"
    [10,17]="Pixhelf        画廊相册"
    [10,18]="StorageUI      S3与R2文件管理"
    [10,19]="WZFileManager  文件管理"
    [10,20]="imgli          图床项目"
    [10,21]="Pixtale        画廊相册"
    [10,22]="PocketDrive    口袋网盘"
    [10,23]="PicHost        图床项目"
    [11,1]="SaveAnyBot   TG转存文件"
    [11,2]="TeleBoxTG    TG人形机器人"
    [11,3]="LangBot      AI即时通信机器人"
    [11,4]="LLBot        QQ机器人"
    [11,5]="AstrBot      聊天机器人"
    [11,6]="koipy        测速机器人"
    [11,7]="MiaoSpeed    测速后端"
    [11,8]="FlClouds     TG转存网盘"
    [12,1]="MCSManager       游戏开服"
    [12,2]="PuppyStardew     星露谷物语开服"
    [12,3]="Ice-Climber      敲冰块大逃杀"
    [12,4]="Arena Brawl      大乱斗网页游戏"
    [12,5]="Bomb Party       炸弹派对"
    [13,1]="Y 探长        甲骨文云助手 "
    [13,2]="OCI-Start     甲骨文云助手"
    [13,3]="R 探长        甲骨文云助手"
    [13,4]="lookbusy      甲骨文保活"
    [14,1]="FOSSBilling   托管业务"
    [14,2]="Paymenter     托管业务"
    [14,3]="PayIncus      托管业务"
    [14,4]="PVE           切割小鸡"
    [14,5]="LXC           切割小鸡"
    [14,6]="Docker        切割小鸡"
    [14,7]="Incus         切割小鸡"
    [14,8]="LXDAPI        切割小鸡"
    [14,9]="CLICD         切割小鸡"
    [14,10]="IDCONEMAN     托管业务"
    [15,1]="OpenClaw           AI助手"
    [15,2]="HermesAgent        AI助手"
    [15,3]="NEWAPI             AI模型聚合网关"
    [15,4]="CLIProxyAPI        AI模型聚合网关"
    [15,5]="Sub2API            AI模型聚合网关"
    [15,6]="CliRelay           AI模型聚合网关"
    [15,7]="AntigravityTools   AI模型聚合网关"
    [15,8]="gcli2api           AI模型聚合网关"
    [15,9]="octopusAPI         AI模型聚合网关"
    [15,10]="AIClient2API       AI模型聚合网关"
    [15,11]="GeminiBusiness2API AI模型聚合网关"
    [15,12]="MiMo2API           AI模型聚合网关"
    [15,13]="baiduchat2api      AI模型聚合网关"
    [15,14]="Codeg              智能体编码工作台"
    [15,15]="Huobao-Drama       短剧生成"
    [15,16]="GPTImage           图片生成"
    [15,17]="ImagePlayground    图片生成"
    [15,18]="ModelStatus        模型监控"
    [15,19]="CPAUsageKeeperCPA  用量追踪"
    [15,20]="GptSession         Sub2API&CPA凭证转换工具"
    [15,21]="DrissionPage       网页自动化工具"
    [15,22]="Open  WebUI        Web面板"
    [15,23]="Codex WebUI        Web面板"
    [15,24]="Gemini CLI         CLI工具"
    [15,25]="Open Code          CLI工具"
    [15,26]="Code Whale         CLI工具"
    [15,27]="Claude Code        CLI工具"
    [15,28]="Codex CLI          CLI工具"
)

# ================== 二级菜单命令 ==================
declare -A commands=(
    [1,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Dockersos.sh)'
    [1,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockercompose.sh)'
    [1,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Dockcompbauck.sh)'
    [1,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockerupdate.sh)'
    [1,5]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/dockerbots.sh)'
    [2,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MySQLD.sh)'
    [2,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/PostgreSQL.sh)'
    [2,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Redis.sh)'
    [2,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MongoDB.sh)'
    [2,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MariaDB.sh)'
    [2,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DBX.sh)'
    [2,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Lucky.sh)'
    [2,8]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Nginxos.sh)'
    [2,9]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Nginx6os.sh)'
    [2,10]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Caddyos.sh)'
    [2,11]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/Acmeos.sh)'
    [3,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Wallos.sh)'
    [3,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Renewlet.sh)'
    [3,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Subtracker.sh)'
    [3,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EasySub.sh)'
    [3,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Vaultwarden.sh)'
    [3,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/2FAuth.sh)'
    [3,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Pocket-ID.sh)'
    [3,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Tinyauth.sh)'
    [3,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Subs-Check.sh)'
    [3,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MiaoMiaoWu.sh)'
    [3,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Sub-Store.sh)'
    [3,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Subboost.sh)'
    [3,13]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/TOTP-Share-Dashboard.sh)'
    [3,14]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/PrivateRules.sh)'
    [4,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/UptimeKuma.sh)'
    [4,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/KumaMieru.sh)'
    [4,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Komari.sh)'
    [4,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/NezhaDashboard.sh)'
    [4,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Beszel.sh)'
    [4,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Nodeget.sh)'
    [4,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Apprise.sh)'
    [4,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/WxChatpy.sh)'
    [4,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/CloudEye.sh)'
    [4,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/KomariTrafficHub.sh)'
    [4,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ktui.sh)'
    [4,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Lite.sh)'
    [5,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Dnsmgr.sh)'
    [5,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DDNS-Go.sh)'
    [5,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/AdGuardHome.sh)'
    [5,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/OpenFlare.sh)'
    [5,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/FlareSolverr.sh)'
    [5,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/SafeLine.sh)'
    [5,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/SamWAF.sh)'
    [5,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/GHProxy.sh)'
    [5,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/HubProxy.sh)'
    [5,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/HomeLocationEndpoint.sh)'
    [5,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/CFTUN-UI.sh)'
    [5,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Mantou.sh)'
    [6,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/AList-TvBox.sh)'
    [6,2]='bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"'
    [6,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EmbyServerGF.sh)'
    [6,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Embyserver.sh)'
    [6,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Jellyfin.sh)'
    [6,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MediaStationGo.sh)'
    [6,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MoviePilotV3.sh)'
    [6,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Kaloscope.sh)'
    [6,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Audiobookshelf.sh)'
    [6,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ABS-Ximalaya.sh)'
    [6,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Navidrome.sh)'
    [6,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MusicTagWeb.sh)'
    [6,13]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/TuneScout.sh)'
    [6,14]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/LrcApi.sh)'
    [6,15]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/LogVar.sh)'
    [6,16]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MetaTube.sh)'
    [6,17]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MDCNG.sh)'
    [6,18]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MHTI.sh)'
    [6,19]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/AutoBangumi.sh)'
    [6,20]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ANIRSS.sh)'
    [6,21]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EmbyPulse.sh)'
    [6,22]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EmbyTGBot.sh)'
    [6,23]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Kavita.sh)'
    [6,24]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Suwayomi.sh)'
    [6,25]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Komga.sh)'
    [6,26]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/KoodoReader.sh)'
    [6,27]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/TgtoDrive.sh)'
    [6,28]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MediaryScout.sh)'
    [6,29]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Pansou.sh)'
    [6,30]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MagnetFix.sh)'
    [6,31]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/91w.sh)'
    [6,32]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DecoTVD.sh)'
    [6,33]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/LX-Music.sh)'
    [6,34]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/IPTV-trmas.sh)'
    [6,35]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Emby-In-One.sh)'
    [6,36]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Emby-Proxy-Go.sh)'
    [6,37]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EmbyProxy.sh)'
    [6,38]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Vertex.sh)'
    [6,39]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/IYUUPlus.sh)'
    [6,40]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Reclip.sh)'
    [6,41]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/BiliLive-Tools.sh)'
    [6,42]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Transmission.sh)'
    [6,43]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/qBittorrent-noxos.sh)'
    [6,44]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/OS/qbittorrentos.sh)'
    [6,45]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/qBittorrent.sh)'
    [6,46]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/qBit-Bot.sh)'
    [6,47]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Aria2DK.sh)'
    [6,48]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/GlobalRadio.sh)'
    [6,49]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Kerkerker.sh)'
    [6,50]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Kikoeru.sh)'
    [6,51]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ReadCLI.sh)'
    [6,52]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Bitplay.sh)'
    [6,53]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Aegis-Relay.sh)'
    [6,54]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Animaku.sh)'
    [6,55]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MeTubeS.sh)'
    [6,56]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/nowen-video.sh)'
    [6,57]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/OnePick.sh)'
    [6,58]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Live-Event.sh)'
    [6,59]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Meridian.sh)'
    [6,60]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Fluxdown.sh)'
    [6,61]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DownloadManager.sh)'
    [6,62]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MeBox.sh)'
    [7,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/WordPress.sh)'
    [7,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Halo.sh)'
    [7,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Typecho.sh)'
    [7,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Flarum.sh)'
    [7,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Rhex.sh)'
    [7,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/XiaojuSurvey.sh)'
    [7,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Twikoo.sh)'
    [7,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Artalk.sh)'
    [7,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Umami.sh)'
    [7,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Moe-Counter.sh)'
    [7,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/RemioHome.sh)'
    [7,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/Moments.sh)'
    [7,13]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/MomentsBlog.sh)'
    [7,14]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/PandaWiki.sh)'
    [7,15]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/aaPanel.sh)'
    [7,16]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/kxbaota.sh)'
    [7,17]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/kx1Panelv1.sh)'
    [7,18]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/kx1Panelv2.sh)'
    [7,19]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/KaraKeep.sh)'
    [7,20]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Sun-Panel.sh)'
    [7,21]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/FlatNAS.sh)'
    [7,22]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Qinglong.sh)'
    [7,23]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Baihu.sh)'
    [7,24]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ZhuQue.sh)'
    [7,25]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DaidaiPanel.sh)'
    [7,26]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Cloudflare-panel.sh)'
    [7,27]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/html.sh)'
    [7,28]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/BBS1ORG.sh)'
    [8,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DockerWindows.sh)'
    [8,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/FirefoxJ.sh)'
    [8,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Chromium.sh)'
    [8,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/SearXNG.sh)'
    [8,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ZUrl.sh)'
    [8,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ForgejoGit.sh)'
    [8,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Litegist.sh)'
    [8,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MagicResume.sh)'
    [8,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Translate.sh)'
    [8,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Utilsfun.sh)'
    [8,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/VoceChat.sh)'
    [8,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Paperphone-plus.sh)'
    [8,13]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/posteio.sh)'
    [8,14]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Outlook-Email-Plus.sh)'
    [8,15]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MailGo.sh)'
    [8,16]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Backrest.sh)'
    [8,17]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Vaultfleet.sh)'
    [8,18]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/SiYuanNote.sh)'
    [8,19]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Ech0.sh)'
    [8,20]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Znote.sh)'
    [8,21]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/CookieCloud.sh)'
    [8,22]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/eooceWebSSH.sh)'
    [8,23]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ShadowSSH.sh)'
    [8,24]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Quick-SSH.sh)'
    [8,25]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/DockUP.sh)'
    [8,26]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Watchtowertg.sh)'
    [8,27]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ComposeTool.sh)'
    [8,28]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/OutlookMailVoxi.sh)'
    [8,29]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/OutlookMailHub.sh)'
    [9,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/DuJiaoNext.sh)'
    [9,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/ACG-FAKAD.sh)'
    [9,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/MCY.sh)'
    [9,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Fakabot.sh)'
    [9,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/BEpusdt.sh)'
    [9,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/UPayPro.sh)'
    [9,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Epusdt.sh)'
    [9,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Epay-bot.sh)'
    [10,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Cloudreve.sh)'
    [10,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Filebrowser.sh)'
    [10,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/OpenList.sh)'
    [10,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ApacheWebDAV.sh)'
    [10,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Panel/lsky-pro.sh)'
    [10,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/RandomImageAPI.sh)'
    [10,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EasyImage2.sh)'
    [10,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/EasyImg.sh)'
    [10,9]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/OneImg.sh)'
    [10,10]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/IMGAPI.sh)'
    [10,11]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/ConvertX.sh)'
    [10,12]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Enclosed.sh)'
    [10,13]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Filetransfergo.sh)'
    [10,14]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/FileCodeBox.sh)'
    [10,15]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Send.sh)'
    [10,16]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/015.sh)'
    [10,17]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Pixhelf.sh)'
    [10,18]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/StorageUI.sh)'
    [10,19]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/WzFileManager.sh)'
    [10,20]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/imgli.sh)'
    [10,21]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Pixtale.sh)'
    [10,22]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/PocketDrive.sh)'
    [10,23]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/PicHost.sh)'
    [11,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/SaveAnyBot.sh)'
    [11,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/TeleBox.sh)'
    [11,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/LangBot.sh)'
    [11,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/LLBot.sh)'
    [11,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/AstrBot.sh)'
    [11,6]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Koipy.sh)'
    [11,7]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/Miaospeed.sh)'
    [11,8]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Docker/FlClouds.sh)'
    [12,1]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Games/MCSManager.sh)'
    [12,2]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Games/PuppyStardewServer.sh)'
    [12,3]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Games/IceClimberArenaD.sh)'
    [12,4]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Games/ArenaBrawlD.sh)'
    [12,5]='bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Games/BombParty.sh)'
    [13,1]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Oracle/oci-helper.sh)'
    [13,2]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Oracle/oci-start.sh)'
    [13,3]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Oracle/RBot.sh)'
    [13,4]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/Oracle/lookbusy.sh)'
    [14,1]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/FOSSBilling.sh)'
    [14,2]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/Paymenter.sh)'
    [14,3]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/PayIncus.sh)'
    [14,4]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/PVEGL.sh)'
    [14,5]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/LXD.sh)'
    [14,6]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/DockerLXC.sh)'
    [14,7]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/Incus.sh)'
    [14,8]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/LXDAPI.sh)'
    [14,9]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/CLICD.sh)'
    [14,10]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/NAT/IDC-ONEMAN.sh)'
    [15,1]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/OpenClaw.sh)'
    [15,2]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Hermes.sh)'
    [15,3]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/New-API.sh)'
    [15,4]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/CLIProxyAPI.sh)'
    [15,5]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Sub2API.sh)'
    [15,6]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/CliRelay.sh)'
    [15,7]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Antigravity.sh)'
    [15,8]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/gcli2api.sh)'
    [15,9]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Octopus.sh)'
    [15,10]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/AIClient2API.sh)'
    [15,11]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/GeminiBusiness2API.sh)'
    [15,12]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/MIMO-2API.sh)'
    [15,13]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/BAIDUCHAT2API.sh)'
    [15,14]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Codeg.sh)'
    [15,15]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Huobao-Drama.sh)'
    [15,16]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/GPTImagePanel.sh)'
    [15,17]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/GPTImagePlayground.sh)'
    [15,18]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Model-Status.sh)'
    [15,19]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/CPAUsageKeeper.sh)'
    [15,20]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/Gptsession.sh)'
    [15,21]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/DrissionPage.sh)'
    [15,22]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/OpenWebUI.sh)'
    [15,23]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/CodexWebUI.sh)'
    [15,24]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/GeminiCLI.sh)'
    [15,25]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/OpenCodeCLI.sh)'
    [15,26]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/CodeWhale.sh)'
    [15,27]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/ClaudeCode.sh)'
    [15,28]='bash <(curl -fsSL https://raw.githubusercontent.com/sistarry/toolbox/main/AI/CodexCLI.sh)'

)


# ================== Docker 状态获取函数 ==================
show_docker_status() {
    # 检查系统是否安装了 docker 
    if ! command -v docker &> /dev/null; then
        echo -e "${GREEN}🐳 Docker 状态:${RESET} ${RED}❌ 未安装${RESET}"
        return
    fi

    # 检查 Docker 服务是否在运行
    if ! docker info &> /dev/null; then
        echo -e "${GREEN}🐳 Docker 状态:${RESET} ${RED}🛑 未启动${RESET}"
        return
    fi

    # 获取容器和镜像数量
    # runningCount: 运行中, stoppedCount: 已停止, imageCount: 镜像数
    local running_containers=$(docker ps -q | wc -l)
    local total_containers=$(docker ps -a -q | wc -l)
    local stopped_containers=$((total_containers - running_containers))
    local total_images=$(docker images -q | sort -u | wc -l)

    echo -e "${GREEN}🐳 Docker     :${RESET} ${YELLOW}运行中${RESET}"
    echo -e "${GREEN}🟢 运行容器   :${RESET} ${YELLOW}${running_containers}${RESET}" 
    echo -e "${GREEN}🔴 停止容器   :${RESET} ${YELLOW}${stopped_containers}${RESET}" 
    echo -e "${GREEN}📦 系统镜像   :${RESET} ${YELLOW}${total_images}${RESET}"
}


# ================== 菜单显示函数 ==================
show_category_menu() {
    clear
    echo -e "${ORANGE}${BOLD}╔══════════════════════════════╗${RESET}"
    echo -e "${ORANGE}${BOLD}   应用分类菜单${RESET}${YELLOW}(快捷指令:D/d)    ${RESET}"
    echo -e "${ORANGE}${BOLD}╚══════════════════════════════╝${RESET}"
    show_docker_status
    echo -e "${ORANGE}--------------------------------${RESET}"

    for i in $(seq 1 ${#categories[@]}); do
        printf "${YELLOW}[%02d] %-20s${RESET}\n" "$i" "${categories[$i]}"
    done

    printf "${GREEN}[%02d] %-20s${RESET}\n" 88 "更新"
    printf "${GREEN}[%02d] %-20s${RESET}\n" 99 "卸载"
    printf "${YELLOW}[%02d] %-20s${RESET}\n" 0  "退出"
}

show_app_menu() {
    local cat=$1
    clear
    echo -e "${ORANGE}${BOLD}╔═════════════════════════════╗${RESET}"
    echo -e "${ORANGE}${BOLD}           ${categories[$cat]} ${RESET}"
    echo -e "${ORANGE}${BOLD}╚═════════════════════════════╝${RESET}"

    local i=1
    declare -gA menu_map
    menu_map=()

    keys=()
    for key in "${!apps[@]}"; do
        if [[ $key == $cat,* ]]; then
            keys+=("$key")
        fi
    done

    IFS=$'\n' sorted_keys=($(sort -t, -k2n <<<"${keys[*]}"))
    unset IFS

    for key in "${sorted_keys[@]}"; do
        menu_map[$i]=$key
        printf "${YELLOW}[%02d] %-25s${RESET}\n" "$i" "${apps[$key]}"
        ((i++))
    done

    # 返回上一级菜单
    printf "${GREEN}[0] %-25s${RESET}\n" " 返回"

    # 退出脚本
    printf "${GREEN}[X] %-25s${RESET}\n" " 退出"
}

category_menu_handler() {
    while true; do
        show_category_menu
        read -rp "$(echo -e "${RED}请输入分类编号:${RESET}")" cat_choice
        cat_choice=$(echo "$cat_choice" | xargs)  

        # 检查是否为数字（允许前导零）
        if ! [[ "$cat_choice" =~ ^0*[0-9]+$ ]]; then
            echo -e "${RED}无效选择，请输入数字!${RESET}"
            sleep 1
            continue
        fi

        case "$cat_choice" in
            0|00) exit 0 ;;         
            88) update_script ;;
            99) uninstall_script ;;
            *)
                if [[ -n "${categories[$cat_choice]}" ]]; then
                    app_menu_handler "$cat_choice"
                else
                    echo -e "${RED}无效选择，请重新输入!${RESET}"
                    sleep 1
                fi
            ;;
        esac
    done
}

app_menu_handler() {
    local cat=$1
    while true; do
        show_app_menu "$cat"
        read -rp "$(echo -e "${RED}请输入应用编号:${RESET}")" app_choice
        app_choice=$(echo "$app_choice" | xargs)

        # X/x 直接退出脚本
        if [[ "$app_choice" =~ ^[xX]$ ]]; then
            exit 0
        fi

        # 检查是否为数字（允许前导零）
        if ! [[ "$app_choice" =~ ^0*[0-9]+$ ]]; then
            echo -e "${RED}无效选择，请输入数字!${RESET}"
            sleep 1
            continue
        fi

        # 支持 0 或 00 返回上一级
        if [[ "$app_choice" == "0" || "$app_choice" == "00" ]]; then
            break
        elif [[ -n "${menu_map[$app_choice]}" ]]; then
            key="${menu_map[$app_choice]}"
            
            # 1. 提取原始命令
            local RAW_CMD="${commands[$key]}"
            local EXEC_CMD=""

            # 2. 🌟只有当代理不为空时才做替换，默认直连绝不污染命令
            if [ -n "$CHOSEN_PROXY" ]; then
                EXEC_CMD="${RAW_CMD//https:\/\/raw.githubusercontent.com\//$CHOSEN_PROXYhttps:\/\/raw.githubusercontent.com\/}"
            else
                EXEC_CMD="$RAW_CMD"
            fi
            
            
            # 3. 执行安全的命令
            bash -c "$EXEC_CMD"
        else
            echo -e "${RED}无效选择，请重新输入!${RESET}"
            sleep 1
        fi

        read -rp $'\033[33m按回车返回应用菜单...\033[0m'
    done
}


# ================== 脚本更新与卸载 ==================
update_script() {
    echo -e "${YELLOW}正在更新应用商店...${RESET}"

    local REAL_UPDATE_URL="${CHOSEN_PROXY}${SCRIPT_URL}"

    if curl -fsSL -o "$SCRIPT_PATH.new" "$REAL_UPDATE_URL"; then
        chmod +x "$SCRIPT_PATH.new"
        mv -f "$SCRIPT_PATH.new" "$SCRIPT_PATH"

        ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/d"
        ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/D"

        echo -e "${GREEN}更新完成！${RESET}"
        sleep 1

        exec "$SCRIPT_PATH"
        exit 0
    else
        echo -e "${RED}更新失败，请检查网络！${RESET}"
    fi
}

uninstall_script() {
    rm -f "$SCRIPT_PATH"
    rm -f "$BIN_LINK_DIR/d" "$BIN_LINK_DIR/D"
    echo -e "${RED}卸载完成！${RESET}"
    exit 0
}

# ================== 主循环 ==================
while true; do
    category_menu_handler
done
