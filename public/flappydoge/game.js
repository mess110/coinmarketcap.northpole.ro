var init = function () {
  var canvas = $("#game")[0];
  var ctx = canvas.getContext("2d");

  var paused = false;

  var bg = $('#bg')[0];
  var doge = $('#doge')[0];
  var wall = $('#asteroid')[0];

  var defaultDogeY = canvas.height / 2 - doge.height / 2;
  var dogeX = 50;
  var dogeY = defaultDogeY;
  var acceleration = 0;
  var fallSpeed = 4;
  var score = 0;
  var wallX = canvas.width;
  var wallY = -150;

  var clear = function () {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
  }

  var drawScore = function () {
    ctx.font = '12pt Comic Sans MS';
    ctx.textAlign = 'center';
    ctx.fillStyle = 'white';
    ctx.fillText(score, canvas.width / 2, 20 );
  }

  var drawBackground = function () {
    ctx.drawImage(bg, 0, 0);
    ctx.drawImage(bg, 0, bg.height);
  }

  var drawTouchToStart = function () {
    ctx.drawImage(doge, dogeX, dogeY);

    ctx.font = '30pt Comic Sans MS';
    ctx.textAlign = 'center';
    ctx.fillStyle = 'white';
    ctx.fillText('touch to start', canvas.width/ 2, 3 * canvas.height/ 4 );
  }

  var intersect = function () {
    var r1 = {
      left: dogeX,
      top: dogeY,
      right: dogeX + doge.width,
      bottom: dogeY + doge.height
    };
    var r2 = {
      left: wallX,
      top: wallY,
      right: wallX + 38,
      bottom: wallY + 342
    };
    return !(r2.left > r1.right || 
        r2.right < r1.left || 
        r2.top > r1.bottom ||
        r2.bottom < r1.top);
  }

  var drawGame = function () {
    dogeY += fallSpeed;
    dogeY -= acceleration * 20;
    ctx.drawImage(doge, dogeX, dogeY);
    ctx.drawImage(wall, wallX, wallY);

    wallX -= 5;
    if (wallX + wall.width < 0) {
      wallX = canvas.width;
      score += 1;
      var num = Math.floor(Math.random() * 10) % 2;
      if ( num % 2 == 0 ) {
        wallY = -150 + (Math.floor(Math.random() * 10));
      } else {
        wallY = 200 + (Math.floor(Math.random() * 10));;
      }
    }

    if (acceleration > 0) {
      acceleration -= 0.1;
    } else {
      acceleration += 0.1;
    }
    if (0.1 < acceleration && acceleration < 0.1) {
      acceleration = 0
    }

    if ((dogeY + doge.height > canvas.height) || (dogeY < 0) || intersect() == true) {
      paused = true;
      dogeY = defaultDogeY;
    }
  }

  var loop = function () { 
    clear();
    drawBackground();
    if (paused == true) {
      drawTouchToStart();
    } else {
      drawGame();
    }
    drawScore();
  }

  setInterval(loop, 1000/30); 

  $( "#game" ).click(function(e) {
    e.preventDefault();
    if (paused == true) {
      paused = false;
      score = 0;
      wallX = canvas.width;
      defaultDogeY = canvas.height / 2 - doge.height / 2;
    }

    if (e.offsetY < canvas.height / 2) {
      acceleration = -0.5;
    } else {
      acceleration = 1;
    }
  });
}

$( document ).ready( init );
