<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title></title>
</head>
<body>
<div id="app">
    <span v-text="ssr">SSR 失敗</span>
</div>
<br>
<?php phpinfo(); ?>
</body>
<script src="https://cdn.jsdelivr.net/npm/vue@2.6.14/dist/vue.js"></script>
<script>
    new Vue({
        el: '#app',
        data: {
            ssr: 'SSR 成功',
        }
    })
</script>
</html>
