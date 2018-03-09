# 勤怠登録くん
![result](https://github.com/tabachain/KINTAI/blob/gif/gif/demo.gif)

人事労務freeeに10日前〜1日前の勤怠を登録します。
パソコンのスリープのログを元に入力するので、パソコンを使う人ならば正確に勤怠がつけられます。
休憩は13:00〜14:00の一時間で固定でつけます。

## 動作OS
Macでの動作を想定しています。
## セットアップ
### ruby 2.3.3のインストール
rubyのバージョンは2.3.3を想定しています
rbenvでやる場合は
`rbenv versions`でrubyのバージョンを確認しておいてください。
インストールは以下のようにすすめます
```
rbenv install 2.3.3
rbenv rehash
```

### gemのインストール
```
bundle install --path vendor/bundle
```

### 実行
```
bundle exec ruby kintai.rb
```

### 備考
認証でローカルでsinatraを4567番ポートで立ち上げます。
すでに4567番ポートを使っている場合は
