#include <Arduino.h>
#include <Keypad.h>
#include <LiquidCrystal.h>

const byte FILAS = 4;
const byte COLUMNAS = 4;

char teclas[FILAS][COLUMNAS] = {
  {'1', '4', '7', '*'},
  {'2', '5', '8', '0'},
  {'3', '6', '9', '#'},
  {'A', 'B', 'C', 'D'}
};

byte pinesFilas[FILAS] = {2, 3, 4, 5};
byte pinesColumnas[COLUMNAS] = {6, 7, 8, 9};

Keypad teclado = Keypad(makeKeymap(teclas), pinesFilas, pinesColumnas, FILAS, COLUMNAS);

// Pines paralelos LCD 16x2 (RS, EN, D4..D7)
#define LCD_RS A0
#define LCD_EN A1
#define LCD_D4 A2
#define LCD_D5 A3
#define LCD_D6 A4
#define LCD_D7 A5

LiquidCrystal lcd(LCD_RS, LCD_EN, LCD_D4, LCD_D5, LCD_D6, LCD_D7);

unsigned long cantidadTeclas = 0;

void mostrarTecla(char tecla) {
  lcd.setCursor(0, 1);
  lcd.print("                ");
  lcd.setCursor(0, 1);
  lcd.print("Tecla: ");
  lcd.print(tecla);
}

void setup() {
  // Enlace UART hacia ESP32 (RX GPIO 16)
  Serial.begin(9600);
  teclado.setDebounceTime(30);

  lcd.begin(16, 2);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("PLEGADORA TELAS");
  lcd.setCursor(0, 1);
  lcd.print("Iniciando...");
  delay(1500);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Presiona tecla");
  lcd.setCursor(0, 1);
  lcd.print("Esperando...");
}

void loop() {
  char tecla = teclado.getKey();

  if (tecla != NO_KEY) {
    cantidadTeclas++;
    mostrarTecla(tecla);
    Serial.write(tecla);
  }
}
