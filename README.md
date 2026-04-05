<div align="center">

# GYM CARGAS

### Seu diário de treino inteligente

*Registre, evolua e bata seus recordes*

---

![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![Web](https://img.shields.io/badge/Web-FF6F00?style=for-the-badge&logo=googlechrome&logoColor=white)

</div>

---

## 📱 Sobre o App

O **Gym Cargas** é um aplicativo de academia desenvolvido em Flutter que permite registrar e acompanhar seus treinos de forma completa. Com ele você controla cargas, repetições, séries e visualiza sua evolução ao longo do tempo — tudo sincronizado na nuvem em tempo real.

---

## ✨ Funcionalidades

### 🔐 Autenticação
- Login com **e-mail e senha**
- Login com **Google** (Web e Android)
- Persistência de sessão — continua logado ao fechar o app
- Tela de splash animada

### 💪 Treinos
- Criar treinos com nome, data e múltiplos exercícios
- Registrar **carga e repetições** por série
- Adicionar/remover exercícios e séries dinamicamente
- Selecionar **grupos musculares** trabalhados (múltiplos ao mesmo tempo)
- Marcar treinos como **favoritos ⭐**
- **Editar** treinos já salvos
- **Duplicar** treinos para usar como base
- **Deletar** treinos com confirmação
- Confirmação ao sair sem salvar

### 📊 Dashboard
- Estatísticas em tempo real: total de treinos, treinos na semana, streak 🔥
- Banner motivacional de streak
- Gráfico semanal com **volume proporcional** por dia
- Lista dos últimos 5 treinos
- Tags coloridas de músculos nos cards
- Histórico completo com **busca por nome**

### 📈 Evolução
- Gráfico de linha da carga máxima por exercício ao longo do tempo
- Cards de recorde, evolução em kg e % e número de sessões
- Destaque automático de **PR (Personal Record)** 🏆
- Tabela histórica com variação entre sessões

### 👤 Perfil
- Editar nome de exibição
- Visualizar provedor de login e status do e-mail
- Logout com confirmação

---

## 🛠️ Tecnologias

| Tecnologia | Uso |
|---|---|
| **Flutter** | Framework principal (Android, iOS, Web) |
| **Firebase Auth** | Autenticação de usuários |
| **Cloud Firestore** | Banco de dados em tempo real |
| **Google Sign-In** | Login social |
| **intl** | Formatação de datas |

---

## 🚀 Como rodar o projeto

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) `>=3.0.0`
- [Firebase CLI](https://firebase.google.com/docs/cli)
- Conta no [Firebase](https://firebase.google.com)

### 1. Clone o repositório
```bash
git clone https://github.com/seu-usuario/gym-cargas.git
cd gym-cargas
```

### 2. Instale as dependências
```bash
flutter pub get
```

### 3. Configure o Firebase

> ⚠️ Os arquivos `firebase_options.dart`, `google-services.json` e `GoogleService-Info.plist` não estão incluídos por conterem chaves privadas. Você precisará configurar seu próprio projeto Firebase.

```bash
# Instale o FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure seu projeto Firebase
flutterfire configure
```

### 4. Rode o app
```bash
# Android
flutter run

# Web
flutter run -d chrome
```

---

## 📦 Dependências principais

```yaml
dependencies:
  firebase_core: ^4.5.0
  firebase_auth: ^6.2.0
  cloud_firestore: ^6.1.3
  google_sign_in: ^7.2.0
  intl: ^0.20.2
```

---

## 🗂️ Estrutura do projeto

```
lib/
├── main.dart               # Entrada do app e configuração de tema
├── auth_gate.dart          # Roteamento autenticação
├── splash_screen.dart      # Tela de carregamento animada
├── login.dart              # Tela de login
├── registro.dart           # Tela de cadastro
├── google_auth_service.dart# Serviço de login Google
├── dashboard.dart          # Tela principal
├── novo_treino.dart        # Criar e editar treinos
├── evolucao.dart           # Gráfico de evolução
├── perfil.dart             # Tela de perfil
└── firebase_options.dart   # Configurações Firebase (não incluído — configure o seu)

assets/
├── logo.png
├── bicepsdireito.png
└── bicepsesquerdo.png
```

---

## 🔒 Segurança

- Cada usuário acessa **apenas seus próprios treinos** (filtrado por `userId`)
- Autenticação gerenciada pelo **Firebase Auth**
- Dados armazenados com segurança no **Firestore**

---

<div align="center">

Feito por **Cauã**


</div>
