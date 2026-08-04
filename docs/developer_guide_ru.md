# Руководство разработчика по проекту Every Era War

Данный документ содержит детальное объяснение архитектуры юнитов, логики состояний, а также пошаговое руководство по добавлению спрайтов, покадровой анимации и визуальных эффектов для объектов и деревьев в Godot 4.

---

## 1. Архитектура и логика юнита (`entities/unit.gd`)

Каждый юнит в игре представляет собой объект `Node2D`, сгенерированный скриптом `entities/unit.gd`. Юнит управляется встроенным конечным автоматом (FSM — Finite State Machine).

### 1.1 Основные роли и состояния (`GameData.UnitRole`)
Роли определены в автозагружаемом синглтоне `autoload/game_data.gd`:
```gdscript
enum UnitRole {
	IDLE,       # Бездействие / поиск работы
	BUILDER,    # Строитель (возводит здания)
	GATHERER,   # Добытчик (собирает ресурсы)
	SCOUT,      # Разведчик (исследует карту)
	WARRIOR     # Воин (патрулирует и сражается)
}
```

### 1.2 Главный цикл юнита (`_process(delta)`)
Каждый кадр `_process()` выполняет следующие проверки в строгом порядке:
1. **Гибель в воде (Water Death)**: Проверяет тип тайла в `world_ref.grid[tile.x][tile.y]`. Если юнит оказался на `World.TerrainType.WATER`, вызывается `_die()`.
2. **Задержка смены роли (`role_switch_cooldown`)**: Предотвращает мгновенное фликерирование переключения ролей.
3. **Выполнение текущей роли**: Через оператор `match role` вызывается соответствующий метод обработки (`_process_idle`, `_process_gatherer`, `_process_builder` и т.д.).

### 1.3 Ограничения и правила перемещения (`_move_toward`)
- **Ограничение расстояния (15 клеток)**: Юнит не может удаляться от своей территории дальше, чем на 15 тайлов. Метод `_is_within_leash_range(next_tile)` использует `faction.get_min_tile_distance(next_tile) <= 15.0`. Если юнит выходит за пределы, он автоматически поворачивает назад к `territory_center`.
- **Запрет сбора на чужой территории**: В методе `_is_resource_valid_for_faction(res_node)` проверяется `gm.is_tile_claimed(res_tile, faction)`. Юнит игнорирует ресурсы, расположенные на территории других фракций.
- **Приоритет ресурсов по складу**: Метод `_find_nearest_resource()` проверяет баланс ресурсов фракции и направляет юнита добывать тот ресурс, которого на складе меньше всего.

---

## 2. Как добавить новую логику или роль юнита (Пример)

Допустим, вы хотите добавить новую роль — **Лекарь (HEALER)** или **Фермер (FARMER)**.

### Шаг 1: Добавьте роль в `autoload/game_data.gd`
```gdscript
enum UnitRole {
	IDLE,
	BUILDER,
	GATHERER,
	SCOUT,
	WARRIOR,
	FARMER # Новая роль
}
```

### Шаг 2: Добавьте обработчик состояния в `entities/unit.gd`
В метод `_process(delta)` добавьте ветку в `match role`:
```gdscript
	match role:
		GameData.UnitRole.IDLE:
			_process_idle(delta)
		GameData.UnitRole.FARMER:
			_process_farmer(delta) # Новый метод
```

И реализуйте сам метод:
```gdscript
func _process_farmer(delta: float) -> void:
	# Логика фермера: ищет свободную землю и работает на ней
	if not is_working:
		is_working = true
		task_timer = 5.0
	else:
		task_timer -= delta
		if task_timer <= 0.0:
			faction.add_resource(GameData.ResourceType.WOOD, 10)
			is_working = false
			_set_role(GameData.UnitRole.IDLE)
```

### Шаг 3: Добавьте иконку состояния в `_draw_state_icon()`
```gdscript
	if role == GameData.UnitRole.FARMER:
		# Рисуем зеленый колосок или иконку фермера
		draw_line(Vector2(0, y_offset + 1), Vector2(0, y_offset - 5), Color.GREEN, 1.5)
		return
```

---

## 3. Требования к спрайтам и их форматы в Godot 4

Если вы хотите перевести игру с векторно-процедурной графики на текстурные спрайты, используйте следующие правила подготовки файлов:

### 3.1 Форматы файлов
- **Формат файла**: `.png` с прозрачным альфа-каналом (RGBA8).
- **Размер кадра**:
  - Для юнитов: `16x16` пикселей или `32x32` пикселя.
  - Для деревьев/ресурсов: `16x16` или `16x32` пикселя.
  - Для зданий: `32x32` пикселя (Ратуша), `16x16` пикселей (Дом, Рудник).

### 3.2 Способы организации спрайтов

#### Вариант 1: Спрайтшит / Атлас текстур (Рекомендуется)
Все кадры одной анимации объединяются в один PNG файл сеткой.
- Например: `unit_walk.png` имеющий размер `64x16` пикселей содержит 4 кадра размером `16x16`.
- В Godot узел `Sprite2D` разбивает такой файл с помощью параметров:
  - `Hframes = 4` (количество колонок/кадров по горизонтали).
  - `Vframes = 1` (количество строк по вертикали).

#### Вариант 2: Отдельные PNG файлы для каждого кадра
Каждый кадр хранится в отдельном файле: `unit_walk_0.png`, `unit_walk_1.png`, `unit_walk_2.png`.
- Используется в узле `AnimatedSprite2D` через ресурс `SpriteFrames`.

### 3.3 Четкость пиксельной графики (Pixel Art Import)
Чтобы пиксельная графика в Godot 4 не размывалась:
1. Выберите созданный PNG файл в панели **FileSystem**.
2. Перейдите во вкладку **Import** (вверху слева).
3. В параметре `Texture -> Filter` установите значение **Nearest**.
4. Нажмите кнопку **Reimport**.
5. Или в коде для узла: `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`.

---

## 4. Реализация покадровой анимации (3 способа с кодом)

### Способ 1: Использование `AnimatedSprite2D` + `SpriteFrames` (Самый простой способ)

Создание и переключение покадровой анимации через `AnimatedSprite2D`.

#### Код в `entities/unit.gd`:
```gdscript
var animated_sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 10
	add_to_group("units")
	
	# Создаем и настраиваем AnimatedSprite2D
	animated_sprite = AnimatedSprite2D.new()
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(animated_sprite)
	
	# Загружаем ресурс SpriteFrames (созданный в редакторе или кодом)
	var frames := SpriteFrames.new()
	
	# Загрузка кадров ходьбы
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0) # 8 кадров в секунду
	frames.add_frame("walk", preload("res://assets/units/walk_0.png"))
	frames.add_frame("walk", preload("res://assets/units/walk_1.png"))
	frames.add_frame("walk", preload("res://assets/units/walk_2.png"))
	
	# Загрузка кадров рубки дерева / работы
	frames.add_animation("work")
	frames.set_animation_speed("work", 6.0)
	frames.add_frame("work", preload("res://assets/units/work_0.png"))
	frames.add_frame("work", preload("res://assets/units/work_1.png"))

	animated_sprite.sprite_frames = frames
	animated_sprite.play("walk")

func _process(delta: float) -> void:
	_update_animation_state()

func _update_animation_state() -> void:
	if animated_sprite == null:
		return

	if is_moving:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	elif is_working:
		if animated_sprite.animation != "work":
			animated_sprite.play("work")
	else:
		animated_sprite.stop()
```

---

### Способ 2: Использование `Sprite2D` + Спрайтшит (Кадры по индексу)

Если кадры упакованы в один файл `res://assets/units/unit_spritesheet.png`:

```gdscript
var sprite: Sprite2D
var anim_timer: float = 0.0
const FRAME_DURATION: float = 0.12 # Время одного кадра в секундах

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/units/unit_spritesheet.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Настройка сетки 4х2 (4 кадра по горизонтали, 2 строки)
	sprite.hframes = 4 
	sprite.vframes = 2
	add_child(sprite)

func _process(delta: float) -> void:
	if is_moving:
		anim_timer += delta
		if anim_timer >= FRAME_DURATION:
			anim_timer = 0.0
			# Анимация ходьбы использует первую строку (кадры 0..3)
			sprite.frame = (sprite.frame + 1) % 4
	elif is_working:
		anim_timer += delta
		if anim_timer >= FRAME_DURATION:
			anim_timer = 0.0
			# Анимация работы использует вторую строку (кадры 4..7)
			sprite.frame = 4 + ((sprite.frame - 4 + 1) % 4)
	else:
		sprite.frame = 0 # Стоит на месте
```

---

### Способ 3: Использование `AnimationPlayer` (Продвинутый контроль)

Для сложной покадровой анимации со звуками и событиями:

1. В узел юнита добавляется `Sprite2D` и `AnimationPlayer`.
2. Создаются треки анимации: `walk`, `idle`, `gather`, `die`.
3. Трек анимирует свойство `Sprite2D:frame`.
4. В коде переключение выполняется одной строчкой:
```gdscript
$AnimationPlayer.play("walk")
```

---

## 5. Анимация деревьев (`ResourceNode`)

Деревья создаются в `entities/resource_node.gd`. 

### Способ А: Покадровая анимация рубки/падения дерева

Когда юнит рубит дерево, можно воспроизводить покадровую анимацию через `Sprite2D`:

```gdscript
# В entities/resource_node.gd:

var tree_sprite: Sprite2D

func _ready() -> void:
	z_index = 3
	add_to_group("resources")
	
	if resource_type == GameData.ResourceType.WOOD:
		tree_sprite = Sprite2D.new()
		tree_sprite.texture = preload("res://assets/trees/tree_chop.png")
		tree_sprite.hframes = 3 # 3 кадра: 0 = целое, 1 = в процессе рубки, 2 = спилено
		add_child(tree_sprite)

func update_chop_visual() -> void:
	if tree_sprite == null:
		return
	# Если дерево активнее всего рубят, меняем кадр
	if current_gatherers > 0:
		tree_sprite.frame = 1
	else:
		tree_sprite.frame = 0
```

---

### Способ Б: Плавное процедурное покачивание на ветру (Без файлов картинки)

```gdscript
func _process(_delta: float) -> void:
	# Перерисовываем для анимации покачивания
	queue_redraw()

func _draw() -> void:
	var half := World.TILE_SIZE / 2.0
	var col: Color = GameData.RESOURCE_COLORS.get(resource_type, Color.WHITE)

	match resource_type:
		GameData.ResourceType.WOOD:
			# Плавный сдвиг кроны
			var sway := sin(Time.get_ticks_msec() * 0.003 + position.x) * 1.5
			
			# Тень
			draw_ellipse(Vector2(half + 1, half + 3), 4.5, 2.0, Color(0, 0, 0, 0.35))
			# Ствол
			draw_rect(Rect2(half - 1, half + 1, 2, 4), Color("5c3a1e"))
			# Крона с покачиванием
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(half + sway, half - 4),
					Vector2(half - 4 + sway * 0.5, half + 1),
					Vector2(half + 4 + sway * 0.5, half + 1),
				]),
				col
			)
```

---

## 6. Сводная таблица файлов проекта для модификаций

| Файл | Назначение | Что редактировать для анимации/логики |
| :--- | :--- | :--- |
| [`autoload/game_data.gd`](file:///d:/Godot/Projects/every-era-war/autoload/game_data.gd) | Константы, enum ролей и зданий | Добавление новых ролей, типов ресурсов, констант |
| [`entities/unit.gd`](file:///d:/Godot/Projects/every-era-war/entities/unit.gd) | Логика юнита, FSM, движение, отрисовка | Логика поведения, спрайты `AnimatedSprite2D`, покадровая анимация |
| [`entities/resource_node.gd`](file:///d:/Godot/Projects/every-era-war/entities/resource_node.gd) | Объекты ресурсов (деревья, золото) | Отрисовка деревьев, спрайты покачивания/рубки |
| [`entities/building.gd`](file:///d:/Godot/Projects/every-era-war/entities/building.gd) | Здания (Ратуша, Дома) | Анимация строительства, тени зданий |
| [`core/game_manager.gd`](file:///d:/Godot/Projects/every-era-war/core/game_manager.gd) | Главный менеджер фракций и юнитов | Спавн, объединение в племена, проверка территорий |
