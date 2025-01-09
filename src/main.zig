const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const Player = struct {
    pos: Vector2,
    speed: f32,
    size: f32,
    health: i32,
    color: ray.Color,
};

const Enemy = struct {
    pos: Vector2,
    speed: f32,
    size: f32,
    active: bool,
    color: ray.Color,
};

const Vector2 = struct {
    x: f32,
    y: f32,

    fn add(self: Vector2, other: Vector2) Vector2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    fn scale(self: Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }
};

const Particle = struct {
    pos: Vector2,
    velocity: Vector2,
    color: ray.Color,
    lifetime: f32,
    active: bool,
};

const Star = struct {
    pos: Vector2,
    brightness: f32,
};

const MAX_PARTICLES = 100;
const MAX_ENEMIES = 5;
const MAX_STARS = 100;

pub fn main() !void {
    ray.InitWindow(800, 600, "Space Survivor");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var player = Player{
        .pos = .{ .x = 400, .y = 300 },
        .speed = 5.0,
        .size = 20,
        .health = 100,
        .color = ray.SKYBLUE,
    };

    var enemies: [MAX_ENEMIES]Enemy = undefined;
    var particles: [MAX_PARTICLES]Particle = undefined;
    var stars: [MAX_STARS]Star = undefined;
    var score: i32 = 0;
    var game_over = false;

    var prng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
    var random = prng.random();

    // Initialize enemies
    for (&enemies) |*enemy| {
        enemy.* = createEnemy(&random);
    }

    // Initialize particles
    for (&particles) |*particle| {
        particle.active = false;
    }

    // Initialize stars
    for (&stars) |*star| {
        star.* = .{
            .pos = .{
                .x = random.float(f32) * 800,
                .y = random.float(f32) * 600,
            },
            .brightness = random.float(f32),
        };
    }

    var score_text: [32]u8 = undefined;
    var health_text: [32]u8 = undefined;

    while (!ray.WindowShouldClose()) {
        if (!game_over) {
            updatePlayer(&player);
            updateEnemies(&enemies, &player, &score, &random);
            updateParticles(&particles);

            if (checkCollisions(&player, &enemies)) {
                player.health -= 5;
                spawnParticles(&particles, player.pos, 10, ray.RED);
                if (player.health <= 0) {
                    game_over = true;
                    spawnParticles(&particles, player.pos, 30, ray.GOLD);
                }
            }
        }

        // Draw
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);

        // Draw stars
        for (stars) |star| {
            const alpha = 0.3 + star.brightness * 0.7;
            ray.DrawCircleV(.{ .x = star.pos.x, .y = star.pos.y }, 1 + star.brightness, ray.ColorAlpha(ray.WHITE, alpha));
        }

        // Draw particles
        for (particles) |particle| {
            if (particle.active) {
                ray.DrawCircleV(.{ .x = particle.pos.x, .y = particle.pos.y }, 2, particle.color);
            }
        }

        if (!game_over) {
            drawPlayer(player);
        }

        for (enemies) |enemy| {
            if (enemy.active) {
                ray.DrawCircleV(.{ .x = enemy.pos.x, .y = enemy.pos.y }, enemy.size, enemy.color);
            }
        }

        if (std.fmt.bufPrint(&score_text, "Score: {d}", .{score})) |text| {
            ray.DrawText(text.ptr, 10, 10, 20, ray.WHITE);
        } else |_| {}

        if (std.fmt.bufPrint(&health_text, "Health: {d}", .{player.health})) |text| {
            ray.DrawText(text.ptr, 10, 40, 20, ray.WHITE);
        } else |_| {}

        if (game_over) {
            ray.DrawText("Game Over!", 300, 250, 40, ray.RED);
            ray.DrawText("Press R to Restart", 270, 300, 30, ray.WHITE);

            if (ray.IsKeyPressed(ray.KEY_R)) {
                player.health = 100;
                player.pos = .{ .x = 400, .y = 300 };
                score = 0;
                game_over = false;

                for (&enemies) |*enemy| {
                    enemy.* = createEnemy(&random);
                }

                for (&particles) |*particle| {
                    particle.active = false;
                }
            }
        }
    }
}

fn updatePlayer(player: *Player) void {
    var movement = Vector2{ .x = 0, .y = 0 };

    if (ray.IsKeyDown(ray.KEY_RIGHT)) movement.x += 1;
    if (ray.IsKeyDown(ray.KEY_LEFT)) movement.x -= 1;
    if (ray.IsKeyDown(ray.KEY_DOWN)) movement.y += 1;
    if (ray.IsKeyDown(ray.KEY_UP)) movement.y -= 1;

    if (movement.x != 0 and movement.y != 0) {
        const norm = @sqrt(@as(f32, 2.0)) / 2.0;
        movement = movement.scale(norm);
    }

    player.pos = player.pos.add(movement.scale(player.speed));

    player.pos.x = @min(@max(player.pos.x, player.size), 800 - player.size);
    player.pos.y = @min(@max(player.pos.y, player.size), 600 - player.size);
}

fn createEnemy(random: *std.rand.Random) Enemy {
    const side = random.intRangeAtMost(u8, 0, 3);
    var pos = Vector2{ .x = 0, .y = 0 };

    switch (side) {
        0 => {
            pos.x = random.float(f32) * 800;
            pos.y = -20;
        },
        1 => {
            pos.x = 820;
            pos.y = random.float(f32) * 600;
        },
        2 => {
            pos.x = random.float(f32) * 800;
            pos.y = 620;
        },
        else => {
            pos.x = -20;
            pos.y = random.float(f32) * 600;
        },
    }

    return Enemy{
        .pos = pos,
        .speed = 2.0 + random.float(f32) * 2.0,
        .size = 10,
        .active = true,
        .color = ray.RED,
    };
}

fn updateEnemies(enemies: []Enemy, player: *const Player, score: *i32, random: *std.rand.Random) void {
    for (enemies) |*enemy| {
        if (!enemy.active) {
            enemy.* = createEnemy(random);
            continue;
        }

        const dir = Vector2{
            .x = player.pos.x - enemy.pos.x,
            .y = player.pos.y - enemy.pos.y,
        };
        const dist = @sqrt(dir.x * dir.x + dir.y * dir.y);

        if (dist > 0) {
            const normalized = Vector2{
                .x = dir.x / dist,
                .y = dir.y / dist,
            };
            enemy.pos = enemy.pos.add(normalized.scale(enemy.speed));
        }

        if (enemy.pos.x < -50 or enemy.pos.x > 850 or
            enemy.pos.y < -50 or enemy.pos.y > 650)
        {
            enemy.* = createEnemy(random);
            score.* += 10;
        }
    }
}

fn checkCollisions(player: *const Player, enemies: []const Enemy) bool {
    for (enemies) |enemy| {
        if (!enemy.active) continue;

        const dx = player.pos.x - enemy.pos.x;
        const dy = player.pos.y - enemy.pos.y;
        const distance = @sqrt(dx * dx + dy * dy);

        if (distance < player.size + enemy.size) {
            return true;
        }
    }
    return false;
}

fn spawnParticles(particles: []Particle, pos: Vector2, count: usize, color: ray.Color) void {
    var spawned: usize = 0;
    for (particles) |*particle| {
        if (spawned >= count) break;
        if (particle.active) continue;

        const angle = @as(f32, @floatFromInt(spawned)) * (std.math.pi * 2.0 / @as(f32, @floatFromInt(count)));
        particle.* = .{
            .pos = pos,
            .velocity = .{
                .x = @cos(angle) * 3,
                .y = @sin(angle) * 3,
            },
            .color = color,
            .lifetime = 1.0,
            .active = true,
        };
        spawned += 1;
    }
}

fn updateParticles(particles: []Particle) void {
    for (particles) |*particle| {
        if (!particle.active) continue;

        particle.pos = particle.pos.add(particle.velocity);
        particle.lifetime -= 0.016;

        if (particle.lifetime <= 0) {
            particle.active = false;
        }
    }
}

fn drawPlayer(player: Player) void {
    ray.DrawCircleV(.{ .x = player.pos.x, .y = player.pos.y }, player.size, player.color);

    const trail_offset: f32 = 15;
    ray.DrawTriangle(.{ .x = player.pos.x - 10, .y = player.pos.y + trail_offset }, .{ .x = player.pos.x, .y = player.pos.y + trail_offset + 10 }, .{ .x = player.pos.x + 10, .y = player.pos.y + trail_offset }, ray.ORANGE);
}
