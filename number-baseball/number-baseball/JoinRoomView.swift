import SwiftUI

private enum JoinMode: String {
  case code
  case browse
}

struct JoinRoomView: View {
  @EnvironmentObject var svc: RoomService
  @EnvironmentObject var loc: LocalizationManager
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var code = ""
  @State private var joinMode: JoinMode = .code
  @State private var groupFilter = ""

  var body: some View {
    VStack(spacing: 0) {
      // Name input (always visible)
      VStack(alignment: .leading, spacing: 6) {
        Text(loc.t("join.myInfo"))
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 4)
        TextField(loc.t("join.name"), text: $name)
          .padding(10)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .padding(.horizontal)
      .padding(.top, 12)
      .padding(.bottom, 8)

      // Mode picker
      Picker(loc.t("join.title"), selection: $joinMode) {
        Text(loc.t("join.enterCode")).tag(JoinMode.code)
        Text(loc.t("join.browsePublic")).tag(JoinMode.browse)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.bottom, 8)

      Divider()

      if joinMode == .code {
        privateJoinSection
      } else {
        publicBrowseSection
      }
    }
    .navigationTitle(loc.t("join.title"))
    .navigationBarTitleDisplayMode(.inline)
    .onDisappear {
      svc.stopPublicRoomsListener()
    }
  }

  // MARK: - Private Join (Enter Code)

  private var privateJoinSection: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text(loc.t("join.roomCode"))
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 4)
        TextField("ABCDE", text: $code)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .font(.system(size: 20, weight: .bold, design: .monospaced))
          .multilineTextAlignment(.center)
          .padding(10)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }

      Button {
        svc.joinRoom(code: code, name: name)
        GameAnalytics.roomJoined(method: "code")
        dismiss()
      } label: {
        Text(loc.t("join.button"))
          .font(.system(size: 16, weight: .bold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .disabled(name.isEmpty || code.count < 4)

      Spacer()
    }
    .padding()
  }

  // MARK: - Public Browse

  private var publicBrowseSection: some View {
    VStack(spacing: 0) {
      // Group filter bar
      HStack(spacing: 10) {
        TextField(loc.t("join.groupCodePlaceholder"), text: $groupFilter)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .font(.system(size: 16, weight: .medium, design: .monospaced))
          .padding(8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .frame(maxWidth: 160)
          .onChange(of: groupFilter) { _, newValue in
            // Auto-uppercase and limit to hex chars
            let filtered = String(newValue.uppercased().filter { "0123456789ABCDEF".contains($0) }.prefix(3))
            if filtered != groupFilter { groupFilter = filtered }
          }

        Button {
          if groupFilter.isEmpty {
            svc.listenAllPublicRooms()
          } else {
            svc.listenPublicRooms(groupCode: groupFilter)
          }
        } label: {
          Text(loc.t("join.search"))
            .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.bordered)

        Spacer()
      }
      .padding(.horizontal)
      .padding(.vertical, 10)

      Divider()

      // Room list
      if svc.publicRooms.isEmpty {
        VStack(spacing: 10) {
          Spacer()
          Image(systemName: "magnifyingglass")
            .font(.system(size: 36))
            .foregroundStyle(.tertiary)
          Text(loc.t("join.noPublicRooms"))
            .foregroundStyle(.secondary)
            .font(.subheadline)
          Spacer()
        }
        .frame(maxWidth: .infinity)
      } else {
        List(svc.publicRooms) { room in
          PublicRoomRow(room: room, loc: loc)
            .contentShape(Rectangle())
            .onTapGesture {
              guard !name.isEmpty else {
                svc.errorMessage = loc.t("join.nameRequired")
                return
              }
              svc.joinRoom(code: room.roomCode, name: name)
              GameAnalytics.roomJoined(method: "browse")
              dismiss()
            }
        }
        .listStyle(.plain)
      }
    }
    .onAppear {
      svc.listenAllPublicRooms()
    }
    .onChange(of: joinMode) { _, newValue in
      if newValue == .browse {
        if groupFilter.isEmpty {
          svc.listenAllPublicRooms()
        } else {
          svc.listenPublicRooms(groupCode: groupFilter)
        }
      } else {
        svc.stopPublicRoomsListener()
      }
    }
  }
}

// MARK: - Public Room Row

private struct PublicRoomRow: View {
  let room: PublicRoomEntry
  let loc: LocalizationManager

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(room.hostName)
          .font(.system(size: 16, weight: .semibold))
        HStack(spacing: 8) {
          Text(room.gameMode == "turn"
               ? loc.t("create.turn")
               : loc.t("create.simultaneous"))
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())

          Text(room.groupCode)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }
}
