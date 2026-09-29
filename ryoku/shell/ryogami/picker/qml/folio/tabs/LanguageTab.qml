import QtQuick
import Ryoku.Ui.Singletons

FolioTabData {
    tabKey: "language"
    title: I18n.tr("Language")
    note: I18n.tr("Choose the language used by the picker and settings.")
    sections: [
        {
            title: I18n.tr("Interface language"),
            subtitle: "",
            controls: [
                { id: "general.language",
                  key: "general.language",
                  kind: "dropdown",
                  label: I18n.tr("Language"),
                  help: I18n.tr("System default follows your desktop language. Wallpaper names and tags stay as they are."),
                  options: [{ value: "auto", label: I18n.tr("System default") }, { value: "en-US", label: I18n.tr("English") }, { value: "sv-SE", label: I18n.tr("Svenska") }, { value: "es-ES", label: I18n.tr("Español") }, { value: "pt-BR", label: I18n.tr("Português (Brasil)") }, { value: "ru-RU", label: I18n.tr("Русский") }, { value: "zh-CN", label: I18n.tr("简体中文") }, { value: "ja-JP", label: I18n.tr("日本語") }, { value: "ar-SA", label: I18n.tr("العربية") }, { value: "fr-FR", label: I18n.tr("Français") }, { value: "bn-BD", label: I18n.tr("বাংলা") }, { value: "ur-PK", label: I18n.tr("اردو") }, { value: "hi-IN", label: I18n.tr("हिन्दी") }],
                  dynamic: "languages",
                  store: "shell",
                  search: ["general.language", "language", "system", "default", "dropdown", "auto", "en-us", "sv-se", "es-es", "pt-br", "ru-ru", "zh-cn", "ja-jp", "ar-sa", "fr-fr", "bn-bd", "ur-pk", "hi-in"] }
            ]
        }
    ]
}
