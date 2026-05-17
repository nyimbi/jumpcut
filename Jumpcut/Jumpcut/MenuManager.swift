//
//  MenuManager.swift
//  Jumpcut
//
//  Created by Steve Cook on 2/5/22.
//

import Cocoa

public class MenuManager {
    @IBOutlet public var standard: NSMenu!
    @IBOutlet public var alt: NSMenu!
    weak private var delegate: AppDelegate?

    public var triggerEvent: NSEvent?

    init() {
        standard = NSMenu()
        alt = NSMenu()
        delegate = (NSApplication.shared.delegate as? AppDelegate)!
        standard.delegate = delegate
        alt.delegate = delegate
    }

    private func checkToggle() -> Bool {
        guard let event = self.triggerEvent else { return false }
        return delegate?.checkMenuBehavior(event) ?? false
    }

    public func shouldSelectionPaste() -> Bool {
        var paste =
 UserDefaults.standard.value(forKey: SettingsPath.menuSelectionPastes.rawValue) as? Bool ?? false
        if checkToggle() {
            paste = !paste
        }
        return paste
    }

    private func menuTitle(for clipping: Clipping, extendedFeaturesEnabled: Bool) -> String {
        if extendedFeaturesEnabled && clipping.isFavorite {
            return "[F] \(clipping.shortenedText)"
        }
        return clipping.shortenedText
    }

    private func standardItem(
        forClipping clipping: Clipping,
        position: Int,
        extendedFeaturesEnabled: Bool
    ) -> NSMenuItem {
        let standardItem = NSMenuItem(
            title: menuTitle(for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled),
            action: #selector(self.delegate!.interactions!.menuSelection(sender:)),
            keyEquivalent: ""
        )
        standardItem.representedObject = position
        standardItem.target = delegate!.interactions!
        return standardItem
    }

    private func altItem(
        forClipping clipping: Clipping,
        position: Int,
        pasteEnabled: Bool,
        extendedFeaturesEnabled: Bool
    ) -> NSMenuItem {
        let altItem = NSMenuItem(
            title: menuTitle(for: clipping, extendedFeaturesEnabled: extendedFeaturesEnabled),
            action: nil,
            keyEquivalent: ""
        )
        altItem.representedObject = position
        let submenu = NSMenu()
        altItem.submenu = submenu
        let placeItem = NSMenuItem(
            title: "Copy to pasteboard",
            action: #selector(self.delegate!.interactions!.menuPlace(sender:)),
            keyEquivalent: ""
        )
        let pasteItem = NSMenuItem(
            title: "Paste",
            action: #selector(self.delegate!.interactions!.menuPaste(sender:)),
            keyEquivalent: ""
        )
        pasteItem.isEnabled = pasteEnabled
        let deleteItem = NSMenuItem(
            title: "Delete item",
            action: #selector(self.delegate!.interactions!.menuDelete(sender:)),
            keyEquivalent: ""
        )
        var items = [placeItem, pasteItem]
        if extendedFeaturesEnabled {
            let saveItem = NSMenuItem(
                title: "Save item to file...",
                action: #selector(self.delegate!.interactions!.menuSaveItemToFile(sender:)),
                keyEquivalent: ""
            )
            let favoriteItem = NSMenuItem(
                title: clipping.isFavorite ? "Remove from Favourites" : "Add to Favourites",
                action: #selector(self.delegate!.interactions!.menuToggleFavorite(sender:)),
                keyEquivalent: ""
            )
            items.append(saveItem)
            items.append(favoriteItem)
        }
        items.append(deleteItem)
        for item in items {
            item.target = delegate!.interactions!
            item.representedObject = position
            submenu.addItem(item)
        }
        return altItem
    }

    private func addFavoritesMenu(menu: NSMenu, stack: ClippingStack) {
        let favoritesMenu = NSMenu()
        let favoritesItem = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
        favoritesItem.submenu = favoritesMenu
        let favorites = stack.favoriteItems()
        if favorites.isEmpty {
            let empty = NSMenuItem(title: "<None>", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            favoritesMenu.addItem(empty)
        } else {
            for favorite in favorites {
                let item = NSMenuItem(
                    title: favorite.clipping.shortenedText,
                    action: #selector(self.delegate!.interactions!.menuSelection(sender:)),
                    keyEquivalent: ""
                )
                item.target = delegate!.interactions!
                item.representedObject = favorite.position
                favoritesMenu.addItem(item)
            }
        }
        menu.addItem(favoritesItem)
    }

    public func rebuild(stack: ClippingStack) {
        standard.removeAllItems()
        alt.removeAllItems()
        let extendedFeaturesEnabled = Settings.extendedFeaturesEnabled()
        if stack.isEmpty() {
            for which in [alt!, standard!] {
                which.addItem(withTitle: "<None>", action: nil, keyEquivalent: "")
                which.item(at: 0)!.isEnabled = false
            }
        } else {
            let displaySize: Int
            if let displayNum = UserDefaults.standard.value(forKey: SettingsPath.displayNum.rawValue) as? Int {
                displaySize = displayNum
            } else {
                displaySize = 10
            }
            let clippings = stack.firstItems(n: displaySize)
            // No need to call this N times
            let pasteEnabled = AXIsProcessTrusted()
            for (position, clipping) in clippings.enumerated() {
                standard.addItem(
                    standardItem(
                        forClipping: clipping,
                        position: position,
                        extendedFeaturesEnabled: extendedFeaturesEnabled
                    )
                )
                alt.addItem(
                    altItem(
                        forClipping: clipping,
                        position: position,
                        pasteEnabled: pasteEnabled,
                        extendedFeaturesEnabled: extendedFeaturesEnabled
                    )
                )
            }
        }
        for which in [alt!, standard!] {
            addFixedMenuItems(menu: which, stack: stack, extendedFeaturesEnabled: extendedFeaturesEnabled)
        }
    }

    func addFixedMenuItems(menu: NSMenu, stack: ClippingStack, extendedFeaturesEnabled: Bool) {
        // Shared between alt and standard menus: Clear All, About,
        // Preferences, and Quit
        let appName = ProcessInfo.processInfo.processName
        menu.addItem(NSMenuItem.separator())
        if extendedFeaturesEnabled {
            addFavoritesMenu(menu: menu, stack: stack)
            let saveAllToFile = NSMenuItem(
                title: "Save All to File...",
                action: #selector(self.delegate!.interactions!.saveAllToFile(sender:)),
                keyEquivalent: ""
            )
            saveAllToFile.target = delegate!.interactions!
            saveAllToFile.isEnabled = !stack.isEmpty()
            menu.addItem(saveAllToFile)
            let saveAllAsFiles = NSMenuItem(
                title: "Save All as Files...",
                action: #selector(self.delegate!.interactions!.saveAllAsFiles(sender:)),
                keyEquivalent: ""
            )
            saveAllAsFiles.target = delegate!.interactions!
            saveAllAsFiles.isEnabled = !stack.isEmpty()
            menu.addItem(saveAllAsFiles)
        }
        let clear = NSMenuItem(
            title: "Clear All",
            action: #selector(self.delegate!.interactions!.clearAll(sender:)),
            keyEquivalent: ""
        )
        clear.target = delegate!.interactions!
        menu.addItem(clear)
        menu.addItem(
            NSMenuItem(
                title: "About \(appName)",
                action: #selector(delegate!.openAboutWindow(sender:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Preferences…",
                action: #selector(delegate!.openPreferencesWindow(sender:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(delegate!.quit(sender:)),
                keyEquivalent: ""
            )
        )
    }

}
