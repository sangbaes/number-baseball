import SwiftUI

private enum GroupMode: String {
  case newGroup
  case existingGroup
}

struct CreateRoomView: View {
  @EnvironmentObject var svc: RoomService
  @EnvironmentObject var loc: LocalizationManager
  @State private var name = ""
  @State private var mode = "simultaneous"
  @State private var isPublic = false
  @State private var groupMode: GroupMode = .newGroup
  @State private var selectedGroupCode: String? = nil
  @State private var groupFilter = ""

  var body: some View {
    Form {
      Section(loc.t("create.myInfo")) {
        TextField(loc.t("create.name"), text: $name)
      }
      Section(loc.t("create.mode")) {
        Picker(loc.t("create.mode"), selection: $mode) {
          Text(loc.t("create.simultaneous")).tag("simultaneous")
          Text(loc.t("create.turn")).tag("turn")
        }
        .pickerStyle(.segmented)
      }
      Section(loc.t("create.visibility")) {
        Toggle(loc.t("create.publicToggle"), isOn: $isPublic)
        if isPublic {
          Text(loc.t("create.publicHint"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if isPublic {
        Section(loc.t("create.groupSection")) {
          Picker(loc.t("create.groupMode"), selection: $groupMode) {
            Text(loc.t("create.newGroup")).tag(GroupMode.newGroup)
            Text(loc.t("create.existingGroup")).tag(GroupMode.existingGroup)
          }
          .pickerStyle(.segmented)

          if groupMode == .existingGroup {
            HStack {
              TextField(loc.t("join.groupCodePlaceholder"), text: $groupFilter)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .onChange(of: groupFilter) { _, newValue in
                  let filtered = String(
                    newValue.uppercased()
                      .filter { "0123456789ABCDEF".contains($0) }
                      .prefix(3)
                  )
                  if filtered != groupFilter { groupFilter = filtered }
                }

              Button(loc.t("join.search")) {
                svc.fetchAvailableGroups()
              }
              .buttonStyle(.bordered)
            }

            let filteredGroups = groupFilter.isEmpty
              ? svc.availableGroups
              : svc.availableGroups.filter { $0.groupCode.contains(groupFilter) }

            if filteredGroups.isEmpty {
              Text(loc.t("create.noGroups"))
                .foregroundStyle(.secondary)
                .font(.subheadline)
            } else {
              ForEach(filteredGroups) { group in
                HStack {
                  Text(group.groupCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                  Text("(\(group.roomCount) \(loc.t("create.rooms")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                  if selectedGroupCode == group.groupCode {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(.green)
                  }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                  selectedGroupCode = group.groupCode
                }
              }
            }
          }
        }
      }

      Button(loc.t("create.button")) {
        let groupCode: String? = (isPublic && groupMode == .existingGroup)
          ? selectedGroupCode
          : nil
        svc.createRoom(name: name, mode: mode, isPublic: isPublic, existingGroupCode: groupCode)
        GameAnalytics.roomCreated(mode: mode, isPublic: isPublic)
      }
      .disabled(name.isEmpty || (isPublic && groupMode == .existingGroup && selectedGroupCode == nil))
    }
    .navigationTitle(loc.t("create.title"))
    .onChange(of: isPublic) { _, newValue in
      if newValue {
        svc.fetchAvailableGroups()
      }
    }
    .onChange(of: groupMode) { _, _ in
      selectedGroupCode = nil
    }
  }
}
