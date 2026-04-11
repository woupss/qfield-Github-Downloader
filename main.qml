import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme
import org.qfield
import org.qgis
import QtCore

// =============================================================================
// GithubManager.qml
// Fusion de GithubProjectDownloader + PluginUpdateTool
//
// Onglet 📁 Projet  : téléchargement complet d'un dépôt GitHub vers Imported Projects
// Onglet 🔌 Plugin  : installation d'un plugin + mise à jour des plugins installés
// =============================================================================

Item {
    id: ghDownloader
    property var mainWindow: iface.mainWindow()

    Settings {
    id: updateCacheSettings
    category: "GithubManagerUpdateCache"
    property string cachedResults: ""
    property string cachedAt:      "0"
}

    // =========================================================================
    // 1. INTERFACE PUBLIQUE
    // =========================================================================

    function openUI() {
    mainTabBar.currentIndex = 0
    pluginState = "config"
    pluginCombo.currentIndex = -1
    downloadDialog.open()
}

    // =========================================================================
    // 2. ÉTAT — GithubDownloader
    // =========================================================================

    property string pluginState:    ""
    property var    fileTree:       []
    property var    repoFolders:    []
    property var    downloadQueue:  []
    property int    totalFiles:     0
    property int    processedFiles: 0
    property string baseDestPath:   ""
    property string destMode:       "project"   // "project" | "plugin"
    property int    pluginSubTab:   0           // 0 = Installer, 1 = Mettre à jour (onglet Plugin uniquement)

    property var pluginAuthors: ["woupss", "coastalrocket", "danielseisenbacher",
        "FeelGood-GeoSolutions", "gacarrillor", "HeatherHillers",
        "mbernasocchi", "opengisch", "paul-carteron", "TyHol"]

    property var pluginsByAuthor: ({
        "woupss":              ["qfield-pluginbox", "qfield-filter-plugin", "qfield-DriveMe", "qfield-update-qgz-project",  "qfield-plugin-update", "Github-Downloader", "qfield-theme-position-color"],

        "gacarrillor":   ["qfield-plugin-reloader"],

        "HeatherHillers":["qfield_vegetation_monitoring"],

        "TyHol":               ["DeleteViaDropdown", "Conversion_tools", "KMRT_Plugin", "Qfield_search_Irish_UK_Grid"],

        "danielseisenbacher": ["qfield-image-based-feature-creation", "TrackedFeatureMarker"],

        "paul-carteron":          ["qfield-quicke", "qfield-boxbox", "qfield-cubexp"],

        "coastalrocket":           ["quick_capture", "qfield-osnamesapi-locator"],

        "FeelGood-GeoSolutions": ["FeelGood-OneTapMeasurement", "FeelGood-UITweaker"],
        "mbernasocchi":      ["qfield-layer-loader", "qfield-ask-ai"],

        "opengisch":     ["qfield-geometryless-addition", "qfield-webdav-scheduler"]
    })

    // =========================================================================
    // 3. ÉTAT — PluginUpdateTool (préfixe "up")
    // =========================================================================

    property string upFinalDownloadUrl:   ""
    property string upPreparedUrl:        ""
    property string upTargetUuid:         ""
    property string upTargetName:         ""
    property string upTargetAuthor:       ""
    property string upDetectedVersion:    ""
    property string upInstalledVersion:   ""
    property string upDisplayUrl:         ""
    property string upTargetFolderDisplay:"..."
    property bool   upIsWorking:          false
    property bool   upIsFinished:         false
    property bool   upIsSelfUpdate:       false
    property string upInstalledUuid:      ""
    property bool   upUpdatesChecked:     false
    property var    upPluginsQueue:       []
    property string upUpdatesResultText:  ""
    property bool   upIsCheckingUpdates:  false

    // Dictionnaire plugins connus pour éviter l'API de recherche GitHub
    property var knownRepositories: ({
        "qfield-filter-plugin":              "woupss/qfield-filter-plugin",
        "Github-Downloader":               "woupss/Github-Downloader",
       "qfield-DriveMe":                   "woupss/qfield-DriveMe",
        "qfield-update-qgz-project":         "woupss/qfield-update-qgz-project",
        "qfield-plugin-update":              "woupss/qfield-plugin-update",
        "qfield-theme-position-color":       "woupss/qfield-theme-position-color",
        "qfield-pluginsbox":                 "woupss/qfield-pluginsbox",

        "qfield-plugin-reloader":            "gacarrillor/qfield-plugin-reloader",

        "DeleteViaDropdown":                 "TyHol/DeleteViaDropdown",
        "Conversion_tools":                 "TyHol/Conversion_tools",
        "KMRT_Plugin":                        "TyHol/KMRT_Plugin",
        "Qfield_search_Irish_UK_Grid":       "TyHol/Qfield_search_Irish_UK_Grid",
 
        "FeelGood-UITweaker":                "FeelGood-GeoSolutions/FeelGood-UITweaker",
        "FeelGood-OneTapMeasurement":                "FeelGood-GeoSolutions/FeelGood-OneTapMeasurement",

       "quick_capture":              "coastalrocket/quick_capture",
        "qfield-osnamesapi-locator":              "coastalrocket/qfield-osnamesapi-locator",


        "vocalpoint-qfield-plugin":          "SeqLaz/vocalpoint-qfield-plugin",

        "TrackedFeatureMarker":              "danielseisenbacher/TrackedFeatureMarker",
        "qfield-image-based-feature-creation":              "danielseisenbacher/qfield-image-based-feature-creation",

        "qfield-boxbox":                     "paul-carteron/qfield-boxbox",
        "qfield-cubexp":                     "paul-carteron/qfield-cubexp",
        "qfield-quicke":                     "paul-carteron/qfield-quicke",

        "Qfield-Past-Geometry-Plugin":       "qsavoye/Qfield-Past-Geometry-Plugin",

        "qfield-ask-ai":                     "mbernasocchi/qfield-ask-ai",
        "qfield-layer-loader":               "mbernasocchi/qfield-layer-loader",

        "qfield-osrm":                       "opengisch/qfield-osrm",
        "qfield-geometryless-addition":                       "opengisch/qfield-geometryless-addition",
        "qfield-webdav-scheduler":                       "opengisch/qfield-webdav-scheduler",
        "qfield-nominatim-locator":          "opengisch/qfield-nominatim-locator",
        "qfield-snap":                       "opengisch/qfield-snap",
        "qfield-geomapfish-locator":         "opengisch/qfield-geomapfish-locator",
        "qfield-weather-forecast":           "opengisch/qfield-weather-forecast"
    })

    // =========================================================================
    // 4. TRADUCTIONS — GithubDownloader
    // =========================================================================

    function tr(key) {
        var lang = Qt.locale().name.substring(0, 2)
        var fr = {
            TITLE:            "TÉLÉCHARGEUR GITHUB",
            CB_DEST_PROJECT:  "Projet QField",
            CB_DEST_PLUGIN:   "Plugin QField",
            LBL_OWNER:        "Auteur GitHub :",
            PH_OWNER:         "nom-de-l-auteur",
            LBL_REPO:         "Nom du dépôt GitHub :",
            PH_REPO:          "nom-du-depot",
            LBL_BRANCH:       "Branche :",
            PH_BRANCH:        "main",
            LBL_FOLDER:       "Nom du dossier de votre projet :",
            LBL_FOLDER_PLUGIN:"Nom du dossier du plugin :",
            PH_FOLDER:        "MonProjet",
            CB_TOKEN:         "Token GitHub (dépôt privé / fichiers LFS volumineux)",
            PH_TOKEN:         "ghp_xxxxxxxxxxxx...",
            BTN_EXPLORE:      "🔍  Explorer le dépôt",
            BTN_EXPLORING:    "Exploration en cours…",
            LBL_FILES_FOUND:  "Fichiers trouvés :",
            LBL_DEST:         "Destination locale :",
            RADIO_ALL:        "Tout télécharger",
            RADIO_CUSTOM:     "Choisir les éléments…",
            LBL_SEL_ALL:      "Tout sélectionner / désélectionner",
            COL_NAME:         "Nom",
            COL_FOLDER:       "Dossier dans le dépôt",
            COL_SIZE:         "Taille",
            BTN_DOWNLOAD:     "⬇   Télécharger la sélection",
            BTN_UPDATE:       "🔄  Mettre à jour des fichiers",
            BTN_OPEN:         "▶   Ouvrir le projet",
            BTN_CLOSE:        "Fermer",
            STATUS_EXPLORING: "Exploration du dépôt GitHub…",
            STATUS_DL:        "Téléchargement",
            STATUS_DONE:      "✅  Téléchargement terminé !",
            INFO_DONE:        "Le projet est prêt. Cliquez sur « Ouvrir le projet ».",
            INFO_DONE_PLUGIN: "Le plugin est prêt. Vous pouvez l'activer depuis les paramètres.",
            ERR_FIELDS:       "Remplissez : auteur, dépôt et dossier de destination.",
            ERR_404:          "Dépôt introuvable (404). Vérifiez l'auteur et le nom.",
            ERR_401:          "Accès refusé (401). Dépôt privé — utilisez un token.",
            ERR_TREE:         "Impossible de récupérer l'arborescence.",
            ERR_TRUNCATED:    "⚠  Arbre tronqué (repo très volumineux). Liste partielle.",
            ERR_NO_SEL:       "Aucun fichier sélectionné.",
            ERR_HTTP:         "Erreur HTTP",
            ERR_LFS:          "Erreur LFS",
            ERR_DISK:         "Erreur écriture disque",
            ERR_GPKG:         "Fichier .gpkg invalide (pas SQLite)",
            LBL_ROOT:         "(racine)",
            LBL_KB:           "Ko",
            LBL_MB:           "Mo"
        }
        var en = {
            TITLE:            "GITHUB DOWNLOADER",
            CB_DEST_PROJECT:  "QField Project",
            CB_DEST_PLUGIN:   "QField Plugin",
            LBL_OWNER:        "GitHub Author:",
            PH_OWNER:         "username",
            LBL_REPO:         "GitHub Repository:",
            PH_REPO:          "repo-name",
            LBL_BRANCH:       "Branch:",
            PH_BRANCH:        "main",
            LBL_FOLDER:       "Folder name of your project :",
            LBL_FOLDER_PLUGIN:"Plugin folder name:",
            PH_FOLDER:        "MyProject",
            CB_TOKEN:         "GitHub Token (private repo / LFS large files)",
            PH_TOKEN:         "ghp_xxxxxxxxxxxx...",
            BTN_EXPLORE:      "🔍  Explore repository",
            BTN_EXPLORING:    "Exploring…",
            LBL_FILES_FOUND:  "Files found:",
            LBL_DEST:         "Local destination:",
            RADIO_ALL:        "Download all",
            RADIO_CUSTOM:     "Select items…",
            LBL_SEL_ALL:      "Select / deselect all",
            COL_NAME:         "Name",
            COL_FOLDER:       "Folder in repo",
            COL_SIZE:         "Size",
            BTN_DOWNLOAD:     "⬇   Download selection",
            BTN_UPDATE:       "🔄  Update files",
            BTN_OPEN:         "▶   Open project",
            BTN_CLOSE:        "Close",
            STATUS_EXPLORING: "Exploring GitHub repository…",
            STATUS_DL:        "Downloading",
            STATUS_DONE:      "✅  Download complete!",
            INFO_DONE:        "Project ready. Click 'Open project'.",
            INFO_DONE_PLUGIN: "Plugin ready. You can enable it from the settings.",
            ERR_FIELDS:       "Please fill in: author, repository and destination folder.",
            ERR_404:          "Repository not found (404). Check author and repo name.",
            ERR_401:          "Access denied (401). Private repo — use a GitHub token.",
            ERR_TREE:         "Failed to fetch repository tree.",
            ERR_TRUNCATED:    "⚠  Tree truncated (very large repo). Partial list.",
            ERR_NO_SEL:       "No files selected.",
            ERR_HTTP:         "HTTP error",
            ERR_LFS:          "LFS error",
            ERR_DISK:         "Disk write error",
            ERR_GPKG:         "Invalid .gpkg (not SQLite)",
            LBL_ROOT:         "(root)",
            LBL_KB:           "KB",
            LBL_MB:           "MB"
        }
        var d = (lang === "fr") ? fr : en
        return (d[key] !== undefined) ? d[key] : key
    }

    // =========================================================================
    // 5. TRADUCTIONS — PluginUpdateTool
    // =========================================================================

    property var upTranslations: ({
        "up_title":           { "en": "UPDATE INSTALLED PLUGIN",       "fr": "METTRE À JOUR UN PLUGIN INSTALLÉ" },
        "select_placeholder": { "en": "Select an installed plugin",    "fr": "Sélectionnez un plugin installé" },
        "or_custom":          { "en": "OR custom GitHub URL:",         "fr": "OU une URL GitHub personnalisée :" },
        "destination":        { "en": "Target folder:",                "fr": "Dossier cible :" },
        "installed_ver":      { "en": "Installed version: ",           "fr": "Version installée : " },
        "btn_wait":           { "en": "WAIT...",                       "fr": "ATTENTE..." },
        "btn_install":        { "en": "INSTALL NOW",                   "fr": "INSTALLER" },
        "btn_update":         { "en": "UPDATE",                        "fr": "METTRE À JOUR" },

        "Mettre à jour":         { "en": "UPDATE",                        "fr": "METTRE À JOUR" },
        "Installer":         { "en": "INSTALL",                        "fr": "INSTALLER" },

        "status_checking":    { "en": "Checking for updates...",       "fr": "Recherche de mises à jour..." },
        "status_scanning":    { "en": "🔍 Scanning installed plugins...","fr": "🔍 Scan des plugins..." },
        "status_uptodate":    { "en": "✔ All plugins are up to date.", "fr": "✔ Tout est à jour." },
        "status_updates_found":{ "en": "🚀 Updates found:\n",          "fr": "🚀 Mises à jour trouvées :\n" },
        "search_step":        { "en": "Searching",                     "fr": "Recherche" },
        "source_direct":      { "en": "Source: Direct Link",           "fr": "Source : Lien direct" },
        "wait_search":        { "en": "Please wait for search to finish...","fr": "Attendez la fin de la recherche..." },
        "select_warn":        { "en": "⚠️ Please select a plugin.",    "fr": "⚠️ Sélectionnez un plugin." },
        "check_release":      { "en": "Checking releases...",          "fr": "Vérification des versions..." },
        "json_error":         { "en": "JSON Error.",                   "fr": "Erreur JSON." },
        "api_error":          { "en": "API Error",                     "fr": "Erreur API" },
        "ratelimit_error":    { "en": "⚠️ GitHub Rate Limit (403). Try later.", "fr": "⚠️ Limite GitHub (403). Réessayez." },
        "no_repo":            { "en": "❌ No relevant repository found.", "fr": "❌ Aucun dépôt trouvé." },
        "available":          { "en": "Available: ",                   "fr": "Disponible : " },
        "found":              { "en": "Found: ",                       "fr": "Trouvé : " },
        "no_zip":             { "en": "No zip found. Using Main.",     "fr": "Aucun zip. Utilisation de Main." },
        "downloading":        { "en": "Downloading",                   "fr": "Téléchargement" },
        "extracting":         { "en": "Extracting files...",           "fr": "Extraction des fichiers..." },
        "error":              { "en": "❌ Error: ",                    "fr": "❌ Erreur : " },
        "installed":          { "en": "✔ Installed",                   "fr": "✔ Installé" },
        "restart":            { "en": "\nRestart recommended.",        "fr": "\nRedémarrage recommandé." },
        "Refresh the list of plugins to update":       { "en": "🔄  Refresh the list of plugins to update",          "fr": "🔄  Actualiser la liste des plugin à mettre à jour" },
        "plugin_updated":  { "en": "The plugin has been updated.", "fr": "Le plugin a été mis à jour." },
        "btn_reload":      { "en": "🔄  Reload plugin",            "fr": "🔄  Recharger le plugin" },
        "toast_reloading": { "en": "Reloading plugin...",          "fr": "Rechargement du plugin..." } 
    })

    function upTr(key) {
        var lang = Qt.locale().name.substring(0, 2)
        var t = upTranslations[key]
        if (!t) return key
        return t[lang] || t["en"] || key
    }

    // =========================================================================
    // 6. HELPERS — GithubDownloader
    // =========================================================================

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(toolBtn)
    }

    QfToolButton {
        id: toolBtn
        iconSource: 'icon.svg'
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true
        onClicked: ghDownloader.openUI()
    }

    function getOwner()  { return ownerCombo.editText.trim() }
    function getRepo()   {
        return (destMode === "plugin") ? repoCombo.editText.trim()
                                       : repoInput.text.trim()
    }
    function getBranch() {
        var b = branchInput.text.trim()
        return (b !== "") ? b : "main"
    }
    function getFolder() { return folderInput.text.trim() }
    function getToken() {
        return (useTokenCheckbox.checked && tokenInput.text.trim() !== "")
            ? tokenInput.text.replace(/\s/g, "")
            : ""
    }

    function buildDownloadUrl(filePath) {
        var encodedPath = filePath.split("/")
            .map(function(s) { return encodeURIComponent(s) })
            .join("/")
        return "https://api.github.com/repos/"
            + getOwner() + "/" + getRepo()
            + "/contents/" + encodedPath
            + "?ref=" + getBranch()
    }

    function getRepoLfsUrl() {
        return "https://github.com/" + getOwner() + "/" + getRepo()
            + ".git/info/lfs/objects/batch"
    }

    function computeBaseDestPath() {
        var folder = getFolder()
        if (folder === "") folder = "projet_github"
        var appDir = platformUtilities.applicationDirectory()
        if (appDir && appDir !== "") {
            var appDirLower = appDir.toLowerCase()
            if (destMode === "plugin") {
                var filesBase = appDir
                if (appDirLower.indexOf("imported projects") !== -1
                        || appDirLower.indexOf("imported_projects") !== -1) {
                    filesBase = appDir.substring(0, appDir.lastIndexOf("/"))
                }
                return filesBase + "/QField/plugins/" + folder
            }
            var importedDir = appDir
            if (appDirLower.indexOf("imported projects") === -1
                    && appDirLower.indexOf("imported_projects") === -1) {
                importedDir = appDir + "/Imported Projects"
            }
            return importedDir + "/" + folder
        }
        var root = qgisProject.homePath ? qgisProject.homePath.toString() : ""
        if (root.indexOf("file://") === 0) root = root.substring(7)
        root = decodeURIComponent(root)
        var markers = ["/Imported Projects/", "/imported_projects/"]
        for (var m = 0; m < markers.length; m++) {
            var markerIdx = root.indexOf(markers[m])
            if (markerIdx >= 0) {
                if (destMode === "plugin") {
                    var filesBase2 = root.substring(0, markerIdx)
                    return filesBase2 + "/QField/plugins/" + folder
                }
                return root.substring(0, markerIdx) + markers[m] + folder
            }
        }
        if (destMode === "plugin")
            return "/storage/emulated/0/Android/data/ch.opengis.qfield_dev/files/QField/plugins/" + folder
        return "/storage/emulated/0/Android/data/ch.opengis.qfield_dev/files/Imported Projects/" + folder
    }

    function buildDestPath(subFolder, fileName) {
        var p = baseDestPath
        if (subFolder && subFolder !== "") p = p + "/" + subFolder
        return p + "/" + fileName
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " " + tr("LBL_KB")
        return (bytes / (1024 * 1024)).toFixed(1) + " " + tr("LBL_MB")
    }

    // =========================================================================
    // 7. PHASE EXPLORATION — GithubDownloader
    // =========================================================================

    function startExplore() {
        dummyFocus.forceActiveFocus()
        Qt.inputMethod.hide()
        if (destMode === "plugin" && getRepo() !== "" && getFolder() === "")
            folderInput.text = getRepo()
        if (getOwner() === "" || getRepo() === "") {
            statusText.text  = tr("ERR_FIELDS")
            statusText.color = "red"
            return
        }
        pluginState      = "exploring"
        statusText.text  = tr("STATUS_EXPLORING")
        statusText.color = Theme.mainColor
        infoText.text    = ""
        fileTree         = []
        fileListModel.clear()

        var branchUrl = "https://api.github.com/repos/"
            + getOwner() + "/" + getRepo()
            + "/branches/" + getBranch()
        var xhr = new XMLHttpRequest()
        xhr.open("GET", branchUrl)
        xhr.setRequestHeader("Accept", "application/vnd.github.v3+json")
        var tkn = getToken()
        if (tkn !== "") xhr.setRequestHeader("Authorization", "Bearer " + tkn)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    var branchData = JSON.parse(xhr.responseText)
                    var treeSha = branchData.commit.commit.tree.sha
                    fetchTreeBySha(treeSha)
                } catch(e) {
                    setConfigError(tr("ERR_TREE") + " (branche introuvable: " + e + ")")
                }
            } else if (xhr.status === 404) {
                setConfigError(tr("ERR_404"))
            } else if (xhr.status === 401 || xhr.status === 403) {
                setConfigError(tr("ERR_401"))
            } else {
                setConfigError(tr("ERR_TREE") + " HTTP " + xhr.status)
            }
        }
        xhr.send()
    }

    function fetchTreeBySha(treeSha) {
        var treeUrl = "https://api.github.com/repos/"
            + getOwner() + "/" + getRepo()
            + "/git/trees/" + treeSha + "?recursive=1"
        var xhr = new XMLHttpRequest()
        xhr.open("GET", treeUrl)
        xhr.setRequestHeader("Accept", "application/vnd.github.v3+json")
        var tkn = getToken()
        if (tkn !== "") xhr.setRequestHeader("Authorization", "Bearer " + tkn)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) {
                try { processTree(JSON.parse(xhr.responseText)) }
                catch(e) { setConfigError(tr("ERR_TREE") + " (" + e + ")") }
            } else if (xhr.status === 404) { setConfigError(tr("ERR_404"))
            } else if (xhr.status === 401 || xhr.status === 403) { setConfigError(tr("ERR_401"))
            } else { setConfigError(tr("ERR_TREE") + " HTTP " + xhr.status) }
        }
        xhr.send()
    }

    function processTree(data) {
        var blobs = []; var folders = []
        if (data.tree) {
            for (var i = 0; i < data.tree.length; i++) {
                var item = data.tree[i]
                var isGitMeta = item.path.split("/").some(function(seg) {
                    return seg === ".git" || seg.indexOf(".git") === 0
                })
                if (isGitMeta) continue
                if (item.type === "tree") { folders.push(item.path); continue }
                if (item.type !== "blob") continue
                var parts     = item.path.split("/")
                var fname     = parts[parts.length - 1]
                var subfolder = (parts.length > 1) ? parts.slice(0, parts.length - 1).join("/") : ""
                blobs.push({ path: item.path, folder: subfolder, filename: fname, size: item.size || 0 })
            }
        }
        // Détection du dossier racine du plugin (ex: repo/plugin-name/main.qml → strip le préfixe)
        // folder = chemin repo original (affiché dans l'arbre)
        // destFolder = chemin de destination réel (utilisé pour le téléchargement)
        var pluginRoot = ""
        if (destMode === "plugin") {
            for (var pi = 0; pi < blobs.length; pi++) {
                if (blobs[pi].filename === "main.qml"
                        && blobs[pi].folder !== ""
                        && blobs[pi].folder.indexOf("/") === -1) {
                    pluginRoot = blobs[pi].folder
                    break
                }
            }
        }
        for (var pk = 0; pk < blobs.length; pk++) {
            var orig = blobs[pk].folder
            if (pluginRoot !== "") {
                if (orig === pluginRoot)
                    blobs[pk].destFolder = ""
                else if (orig.indexOf(pluginRoot + "/") === 0)
                    blobs[pk].destFolder = orig.substring(pluginRoot.length + 1)
                else
                    blobs[pk].destFolder = orig
            } else {
                blobs[pk].destFolder = orig
            }
        }
        fileTree    = blobs
        repoFolders = folders
        buildTreeModel()
        selectAllChk.checked = false
        baseDestPath = computeBaseDestPath()
        var truncated   = (data.truncated === true)
        pluginState     = "ready"
        statusText.text = truncated ? tr("ERR_TRUNCATED") : ""
        statusText.color = truncated ? "#e67e22" : "black"
        infoText.text   = ""
        radioAll.checked = true
    }

    function buildTreeModel() {
        fileListModel.clear()
        var folderSet      = {}
        var folderChildren = {}
        folderSet[""] = true
        folderChildren[""] = { folders: [], fileIdxs: [] }
        for (var ri = 0; ri < repoFolders.length; ri++) {
            var rf = repoFolders[ri]
            if (!folderSet[rf]) { folderSet[rf] = true; folderChildren[rf] = { folders: [], fileIdxs: [] } }
        }
        for (var i = 0; i < fileTree.length; i++) {
            var f = fileTree[i].folder
            if (f !== "" && !folderSet[f]) { folderSet[f] = true; folderChildren[f] = { folders: [], fileIdxs: [] } }
        }
        var allFolders = []
        for (var fk in folderSet) { if (fk !== "") allFolders.push(fk) }
        allFolders.sort()
        for (var ai = 0; ai < allFolders.length; ai++) {
            var fp    = allFolders[ai]
            var pparts = fp.split("/")
            var par   = pparts.length > 1 ? pparts.slice(0, -1).join("/") : ""
            if (!folderChildren[par]) folderChildren[par] = { folders: [], fileIdxs: [] }
            if (folderChildren[par].folders.indexOf(fp) === -1)
                folderChildren[par].folders.push(fp)
        }
        for (var bi = 0; bi < fileTree.length; bi++) {
            var pf = fileTree[bi].folder
            if (!folderChildren[pf]) folderChildren[pf] = { folders: [], fileIdxs: [] }
            folderChildren[pf].fileIdxs.push(bi)
        }
        for (var sk in folderChildren) {
            folderChildren[sk].folders.sort()
            folderChildren[sk].fileIdxs.sort(function(a, b) {
                return fileTree[a].filename.localeCompare(fileTree[b].filename)
            })
        }
        function addNodes(parentKey, depth) {
            var ch = folderChildren[parentKey]; if (!ch) return
            var vis = (depth === 0)
            for (var fi = 0; fi < ch.folders.length; fi++) {
                var fp2   = ch.folders[fi]
                var fName = fp2.split("/").slice(-1)[0]
                fileListModel.append({ nodeType: "folder", displayName: fName,
                    nodeKey: fp2, parentKey: parentKey, depth: depth,
                    expanded: false, visible: vis, isSelected: false, idx: -1, sizeLabel: "" })
                addNodes(fp2, depth + 1)
            }
            for (var gi = 0; gi < ch.fileIdxs.length; gi++) {
                var bIdx = ch.fileIdxs[gi]; var blob = fileTree[bIdx]
                fileListModel.append({ nodeType: "file", displayName: blob.filename,
                    nodeKey: blob.path, parentKey: parentKey, depth: depth,
                    expanded: false, visible: vis, isSelected: false, idx: bIdx,
                    sizeLabel: formatSize(blob.size) })
            }
        }
        addNodes("", 0)
    }

    function toggleFolder(nodeKey) {
        var folderIdx = -1
        for (var i = 0; i < fileListModel.count; i++) {
            var n = fileListModel.get(i)
            if (n.nodeType === "folder" && n.nodeKey === nodeKey) { folderIdx = i; break }
        }
        if (folderIdx === -1) return
        var wasExpanded = fileListModel.get(folderIdx).expanded
        fileListModel.setProperty(folderIdx, "expanded", !wasExpanded)
        if (!wasExpanded) {
            for (var j = 0; j < fileListModel.count; j++) {
                if (fileListModel.get(j).parentKey === nodeKey)
                    fileListModel.setProperty(j, "visible", true)
            }
        } else {
            hideDescendants(nodeKey)
        }
    }

    function hideDescendants(parentKey) {
        for (var i = 0; i < fileListModel.count; i++) {
            var nd = fileListModel.get(i)
            if (nd.parentKey === parentKey) {
                fileListModel.setProperty(i, "visible", false)
                if (nd.nodeType === "folder" && nd.expanded) {
                    fileListModel.setProperty(i, "expanded", false)
                    hideDescendants(nd.nodeKey)
                }
            }
        }
    }

    function setFolderSelected(nodeKey, selected) {
        var prefix = nodeKey + "/"
        for (var i = 0; i < fileListModel.count; i++) {
            var nd = fileListModel.get(i)
            if (nd.nodeKey.indexOf(prefix) === 0)
                fileListModel.setProperty(i, "isSelected", selected)
        }
    }

    function setConfigError(msg) {
        pluginState      = "config"
        statusText.text  = msg
        statusText.color = "red"
        infoText.text    = ""
    }

    // =========================================================================
    // 8. PHASE TÉLÉCHARGEMENT — GithubDownloader
    // =========================================================================

    ListModel { id: fileListModel }

    function startDownload() {
        dummyFocus.forceActiveFocus()
        Qt.inputMethod.hide()
        platformUtilities.requestStoragePermission()
        var queue = []
        if (radioAll.checked) {
            for (var i = 0; i < fileTree.length; i++) queue.push(fileTree[i])
        } else {
            for (var j = 0; j < fileListModel.count; j++) {
                var nd = fileListModel.get(j)
                if (nd.nodeType === "file" && nd.isSelected && nd.idx >= 0)
                    queue.push(fileTree[nd.idx])
            }
        }
        if (queue.length === 0) { mainWindow.displayToast(tr("ERR_NO_SEL")); return }
        downloadQueue  = queue
        totalFiles     = queue.length
        processedFiles = 0
        infoText.text  = ""
        baseDestPath   = computeBaseDestPath()
        pluginState    = "downloading"
        processNextFile()
    }

    function processNextFile() {
        if (downloadQueue.length === 0) { finishDownload(); return }
        var item = downloadQueue[0]
        var info = "(" + (processedFiles + 1) + "/" + totalFiles + ")"
        statusText.text  = tr("STATUS_DL") + " " + info
        statusText.color = Theme.mainColor
        infoText.text    = item.path
        var destPath = buildDestPath(item.destFolder, item.filename)
        var dlUrl    = buildDownloadUrl(item.path)
        var tkn      = getToken()
        ensureDir(item.destFolder)
        downloadSmartFile(dlUrl, destPath, tkn, function() {
            processedFiles++
            downloadQueue.shift()
            Qt.callLater(function() {
                Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 600; repeat: false; running: true;' +
                    '  onTriggered: { ghDownloader.processNextFile(); destroy(); } }',
                    ghDownloader
                )
            })
        })
    }

    function ensureDir(subFolder) {
        var appDir = platformUtilities.applicationDirectory()
        var rel = baseDestPath
        if (rel.indexOf(appDir) === 0) rel = rel.substring(appDir.length)
        if (rel.charAt(0) === "/") rel = rel.substring(1)
        if (subFolder && subFolder !== "") rel = rel + "/" + subFolder
        var segments = rel.split("/")
        var current  = appDir
        for (var i = 0; i < segments.length; i++) {
            var seg = segments[i]; if (!seg) continue
            var target = current + "/" + seg
            if (!FileUtils.fileExists(target)) platformUtilities.createDir(current, seg)
            current = target
        }
    }

    function downloadSmartFile(url, destPath, token, onFinished) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.setRequestHeader("Accept", "application/vnd.github.v3.raw")
        if (token !== "") xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) {
                var text = xhr.responseText
                var isLfs = (text.length < 512 && text.indexOf("version https://git-lfs") === 0)
                if (isLfs) {
                    var lines   = text.split("\n")
                    var oidLine = lines.find(function(l) { return l.indexOf("oid sha256:") === 0 })
                    var sizeLine= lines.find(function(l) { return l.indexOf("size ") === 0 })
                    var oid     = oidLine ? oidLine.replace("oid sha256:", "").trim() : ""
                    var sz      = sizeLine ? parseInt(sizeLine.replace("size ", "").trim()) : 0
                    if (oid !== "") { downloadLfsFile(oid, sz, destPath, token, onFinished); return }
                }
                writeRawFile(xhr, destPath, onFinished)
            } else if (xhr.status === 401 || xhr.status === 403) {
                abortDownload(tr("ERR_401") + " : " + FileUtils.fileName(destPath))
            } else {
                abortDownload(tr("ERR_HTTP") + " " + xhr.status + " : " + FileUtils.fileName(destPath))
            }
        }
        xhr.send()
    }

    function downloadLfsFile(oid, size, destPath, token, onFinished) {
        var lfsReq = { operation: "download", transfers: ["basic"],
            objects: [{ oid: oid, size: size }] }
        var xhr = new XMLHttpRequest()
        xhr.open("POST", getRepoLfsUrl())
        xhr.setRequestHeader("Content-Type", "application/vnd.git-lfs+json")
        xhr.setRequestHeader("Accept",       "application/vnd.git-lfs+json")
        if (token !== "") xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    var resp    = JSON.parse(xhr.responseText)
                    var obj     = resp.objects && resp.objects[0]
                    var dlUrl   = obj && obj.actions && obj.actions.download
                                  ? obj.actions.download.href : ""
                    if (dlUrl === "") { abortDownload(tr("ERR_LFS") + " (no href)"); return }
                    var hdr = obj.actions.download.header || {}
                    downloadBinaryFile(dlUrl, hdr, destPath, onFinished)
                } catch(e) { abortDownload(tr("ERR_LFS") + " JSON: " + e) }
            } else { abortDownload(tr("ERR_LFS") + " HTTP " + xhr.status) }
        }
        xhr.send(JSON.stringify(lfsReq))
    }

    function downloadBinaryFile(url, extraHeaders, destPath, onFinished) {
        var xhr = new XMLHttpRequest()
        xhr.responseType = "arraybuffer"
        xhr.open("GET", url)
        for (var hk in extraHeaders) xhr.setRequestHeader(hk, extraHeaders[hk])
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) { writeRawFile(xhr, destPath, onFinished) }
            else { abortDownload(tr("ERR_HTTP") + " " + xhr.status + " (LFS binary)") }
        }
        xhr.send()
    }

    function writeRawFile(xhr, destPath, onFinished) {
        var cleanPath = destPath
        if (cleanPath.indexOf("file://") === 0) cleanPath = cleanPath.substring(7)
        cleanPath = decodeURIComponent(cleanPath)
        var finalPath = cleanPath
        var isGpkg    = cleanPath.toLowerCase().endsWith(".gpkg")
        var partPath  = cleanPath + ".part"
        if (xhr.status === 200 || xhr.status === 0) {
            if (isGpkg) {
                var hdr = (typeof xhr.response === "string")
                    ? xhr.response.substring(0, 20)
                    : String.fromCharCode.apply(null, new Uint8Array(xhr.response, 0, 20))
                if (hdr.indexOf("SQLite format 3") === -1) {
                    abortDownload(tr("ERR_GPKG") + " : " + FileUtils.fileName(cleanPath)); return
                }
            }
            var home = qgisProject.homePath ? qgisProject.homePath.toString() : ""
            if (home.indexOf("file://") === 0) home = home.substring(7)
            home = decodeURIComponent(home)
            var fileName  = FileUtils.fileName(cleanPath)
            var tmpName   = ".ghd_tmp_" + fileName
            var writePath = (home !== "") ? (home + "/" + tmpName) : (isGpkg ? partPath : cleanPath)
            var ok = FileUtils.writeFileContent(writePath, xhr.response)
            if (!ok) { abortDownload(tr("ERR_DISK") + " (écriture tmp) : " + fileName); return }
            if (home !== "") {
                var moveDest = isGpkg ? partPath : finalPath
                var moved = platformUtilities.renameFile(writePath, moveDest, true)
                if (!moved) { abortDownload(tr("ERR_DISK") + " (déplacement) : " + fileName); return }
            }
            if (isGpkg) {
                var swapped = performSafeFileSwap(finalPath, partPath)
                if (swapped) { if (onFinished) onFinished() }
                else { abortDownload(tr("ERR_DISK") + " (swap) : " + fileName) }
            } else { if (onFinished) onFinished() }
        } else {
            abortDownload(tr("ERR_HTTP") + " " + xhr.status + " : " + FileUtils.fileName(cleanPath))
        }
    }

    function performSafeFileSwap(finalPath, tempPath) {
        var backupPath = finalPath + ".old"
        var walPath    = finalPath + "-wal"; var shmPath = finalPath + "-shm"
        var walBackup  = backupPath + "-wal"
        if (FileUtils.fileExists(walPath)) {
            platformUtilities.renameFile(walPath, walBackup, true)
            if (FileUtils.fileExists(shmPath)) platformUtilities.rmFile(shmPath)
        }
        if (FileUtils.fileExists(finalPath)) {
            if (!platformUtilities.renameFile(finalPath, backupPath, true)) return false
        }
        if (platformUtilities.renameFile(tempPath, finalPath, true)) {
            try {
                if (FileUtils.fileExists(backupPath)) platformUtilities.rmFile(backupPath)
                if (FileUtils.fileExists(walBackup))  platformUtilities.rmFile(walBackup)
            } catch(e) {}
            return true
        }
        return false
    }

    function abortDownload(msg) {
        pluginState      = "ready"
        statusText.text  = "❌  " + msg
        statusText.color = "red"
        infoText.text    = ""
    }

    function finishDownload() {
        pluginState      = "done"
        statusText.text  = tr("STATUS_DONE")
        statusText.color = "#80cc28"
        infoText.text    = (destMode === "plugin") ? tr("INFO_DONE_PLUGIN") : tr("INFO_DONE")
    }

    function findRootProjectFile() {
        for (var i = 0; i < fileTree.length; i++) {
            var fn = fileTree[i].filename.toLowerCase()
            if ((fn.endsWith(".qgz") || fn.endsWith(".qgs")) && fileTree[i].folder === "")
                return baseDestPath + "/" + fileTree[i].filename
        }
        return ""
    }

    // =========================================================================
    // 9. FONCTIONS — PluginUpdateTool
    // =========================================================================

    function cleanVersion(v) {
        if (!v) return ""
        return v.replace(/^[vV]/, "").trim()
    }

    function isNewerVersion(currentVer, onlineVer) {
        var v1 = cleanVersion(currentVer).split('.')
        var v2 = cleanVersion(onlineVer).split('.')
        var len = Math.max(v1.length, v2.length)
        for (var i = 0; i < len; i++) {
            var num1 = (i < v1.length) ? parseInt(v1[i]) : 0
            var num2 = (i < v2.length) ? parseInt(v2[i]) : 0
            if (isNaN(num1)) num1 = 0; if (isNaN(num2)) num2 = 0
            if (num2 > num1) return true; if (num1 > num2) return false
        }
        return false
    }

    function startGlobalUpdateCheck() {
    if (upUpdatesChecked) return

    // ── Vérification du cache (2 heures) ──────────────────────────
    var now = new Date().getTime()
    var cachedAt = parseInt(updateCacheSettings.cachedAt) || 0
    var cacheAgeMs = 2 * 60 * 60 * 1000  // 2 heures
    if (updateCacheSettings.cachedResults !== "" && (now - cachedAt) < cacheAgeMs) {
        upUpdatesResultText = updateCacheSettings.cachedResults
        upIsCheckingUpdates = false
        upUpdatesChecked    = true
        return
    }

    upPluginsQueue        = []
    upUpdatesResultText   = upTr("status_scanning")
    upIsCheckingUpdates   = true
    if (typeof pluginManager === "undefined" || !pluginManager.availableAppPlugins) return
    var plugins = pluginManager.availableAppPlugins
    for (var i = 0; i < plugins.length; i++) {
        var p = plugins[i]
        // ── On ne scanne que les plugins du dictionnaire connu ──────
        var repoSlug = knownRepositories[p.uuid] || knownRepositories[p.name]
        if (repoSlug)
            upPluginsQueue.push({ name: p.name, version: p.version, uuid: p.uuid })
    }
    if (upPluginsQueue.length === 0) {
        upUpdatesResultText = upTr("status_uptodate")
        upIsCheckingUpdates = false
        upUpdatesChecked    = true
        return
    }
    updateQueueTimer.start()
}

    function handleRateLimitError() {
        updateQueueTimer.stop()
        upIsCheckingUpdates = false
        var msg = "\n" + upTr("ratelimit_error")
        if (upUpdatesResultText.indexOf("403") === -1) upUpdatesResultText += msg
        upStatusText.text  = "Error 403: API Limit"
        upStatusText.color = "red"
    }

    function checkSinglePluginUpdate(pluginObj) {
        var repoSlug = knownRepositories[pluginObj.uuid] || knownRepositories[pluginObj.name]
        if (repoSlug) { getLatestTag("https://api.github.com/repos/" + repoSlug, pluginObj); return }
        var query  = encodeURIComponent(pluginObj.name + " qfield")
        var apiUrl = "https://api.github.com/search/repositories?q=" + query + "&sort=stars&order=desc&per_page=1"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        if (response.items && response.items.length > 0)
                            getLatestTag(response.items[0].url, pluginObj)
                    } catch (e) {}
                } else if (xhr.status === 403) { handleRateLimitError() }
            }
        }
        xhr.open("GET", apiUrl); xhr.setRequestHeader("User-Agent", "QField-Plugin-Installer"); xhr.send()
    }

    function getLatestTag(repoUrl, pluginObj) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        var remoteVer = ""
                        if (Array.isArray(response) && response.length > 0)
                            remoteVer = response[0].name || response[0].tag_name
                        else if (response.tag_name) remoteVer = response.tag_name
                        else if (response.name) remoteVer = response.name
                        if (remoteVer !== "" && isNewerVersion(pluginObj.version, remoteVer))
                            appendUpdateMessage(pluginObj.name, pluginObj.version, remoteVer)
                    } catch (e) {}
                } else if (xhr.status === 403) { handleRateLimitError() }
            }
        }
        xhr.open("GET", repoUrl + "/releases/latest")
        xhr.setRequestHeader("User-Agent", "QField-Plugin-Installer"); xhr.send()
    }

    function appendUpdateMessage(name, oldVer, newVer) {
        if (upUpdatesResultText.indexOf("Scanning") !== -1 || upUpdatesResultText.indexOf("Scan") !== -1)
            upUpdatesResultText = upTr("status_updates_found")
        upUpdatesResultText += "• " + name + ": " + oldVer + " ➡ " + newVer + "\n"
    }

    function getRepoSlug(url) {
        if (!url || url.indexOf("github.com") === -1) return ""
        var clean = url.replace("https://github.com/", "").replace("http://github.com/", "")
        clean = clean.split("/archive")[0]; clean = clean.split("/releases")[0]
        var parts = clean.split("/")
        if (parts.length >= 2) return parts[0] + "/" + parts[1]
        return ""
    }

    function startSmartSearch() { searchGitHubBroad(upTargetName + " qfield", 1) }

    function searchGitHubBroad(queryTerm, step) {
        upStatusText.text  = upTr("search_step") + " (" + step + "): '" + queryTerm + "'..."
        upStatusText.color = "gray"
        var apiUrl = "https://api.github.com/search/repositories?q=" + encodeURIComponent(queryTerm) + "&sort=stars&order=desc&per_page=5"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        var items = response.items || []
                        if (items.length > 0) {
                            var bestRepo = findBestMatch(items)
                            if (bestRepo) checkGitHubRelease(bestRepo.full_name, bestRepo.html_url, false)
                            else tryNextSearchStep(step)
                        } else tryNextSearchStep(step)
                    } catch (e) { upStatusText.text = "❌ " + upTr("json_error") }
                } else if (xhr.status === 403) {
                    upStatusText.text  = upTr("ratelimit_error"); upStatusText.color = "red"
                } else { upStatusText.text = "❌ " + upTr("api_error") + " (" + xhr.status + ")" }
            }
        }
        xhr.open("GET", apiUrl); xhr.setRequestHeader("User-Agent", "QField-Plugin-Installer"); xhr.send()
    }

    function tryNextSearchStep(currentStep) {
        if (currentStep === 1) {
            if (upTargetUuid !== "") searchGitHubBroad(upTargetUuid, 2)
            else handleSearchFailure()
        } else if (currentStep === 2) { searchGitHubBroad(upTargetName, 3)
        } else handleSearchFailure()
    }

    function handleSearchFailure() { upStatusText.text = upTr("no_repo"); upStatusText.color = "red" }

    function findBestMatch(items) {
        var bestItem = null; var maxScore = 0; var threshold = 15
        var targetUuidClean   = upTargetUuid.toLowerCase().replace(/_/g, "-")
        var targetAuthorClean = upTargetAuthor.toLowerCase()
        var authorParts       = targetAuthorClean.split(" ")
        var primaryAuthorName = authorParts.length > 0 ? authorParts[0] : targetAuthorClean
        for (var i = 0; i < items.length; i++) {
            var item = items[i]; var score = 0
            var repoName  = item.name.toLowerCase()
            var repoOwner = item.owner.login.toLowerCase()
            var desc      = (item.description || "").toLowerCase()
            if (targetAuthorClean !== "" && (repoOwner.indexOf(primaryAuthorName) !== -1 || targetAuthorClean.indexOf(repoOwner) !== -1)) score += 30
            if (upTargetUuid !== "" && (repoName === targetUuidClean || repoName === upTargetUuid.toLowerCase())) score += 20
            else if (repoName.indexOf(targetUuidClean) !== -1) score += 10
            if (desc.indexOf("qfield") !== -1 || repoName.indexOf("qfield") !== -1) score += 10
            if (item.stargazers_count > 10) score += 5
            if (score > maxScore) { maxScore = score; bestItem = item }
        }
        return maxScore >= threshold ? bestItem : null
    }

    function checkGitHubRelease(repoSlug, fallbackUrl, autoInstall) {
        var apiUrl = "https://api.github.com/repos/" + repoSlug + "/releases/latest?t=" + new Date().getTime()
        if (!autoInstall) upStatusText.text = upTr("check_release")
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) processSingleRelease(xhr.responseText, fallbackUrl, autoInstall)
                else if (xhr.status === 403) { upStatusText.text = upTr("ratelimit_error"); upStatusText.color = "red" }
                else checkGitHubAllReleases(repoSlug, fallbackUrl, autoInstall)
            }
        }
        xhr.open("GET", apiUrl); xhr.setRequestHeader("User-Agent", "QField-Plugin-Installer"); xhr.send()
    }

    function checkGitHubAllReleases(repoSlug, fallbackUrl, autoInstall) {
        var apiUrl = "https://api.github.com/repos/" + repoSlug + "/releases?per_page=1&t=" + new Date().getTime()
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) processListResponse(xhr.responseText, fallbackUrl, autoInstall, "Release")
                else checkGitHubTags(repoSlug, fallbackUrl, autoInstall)
            }
        }
        xhr.open("GET", apiUrl); xhr.setRequestHeader("User-Agent", "QField-Plugin-Installer"); xhr.send()
    }

    function checkGitHubTags(repoSlug, fallbackUrl, autoInstall) {
        var apiUrl = "https://api.github.com/repos/" + repoSlug + "/tags?per_page=1&t=" + new Date().getTime()
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) processListResponse(xhr.responseText, fallbackUrl, autoInstall, "Tag")
                else handleUpError(fallbackUrl, autoInstall, "API Error " + xhr.status + ". Using Main.")
            }
        }
        xhr.open("GET", apiUrl); xhr.setRequestHeader("User-Agent", "QField-Plugin-Installer"); xhr.send()
    }

    function processSingleRelease(jsonText, fallbackUrl, autoInstall) {
        try { extractAndFinish(JSON.parse(jsonText), fallbackUrl, autoInstall) }
        catch (e) { handleUpError(fallbackUrl, autoInstall, upTr("json_error")) }
    }

    function processListResponse(jsonText, fallbackUrl, autoInstall, typeLabel) {
        try {
            var response = JSON.parse(jsonText)
            if (Array.isArray(response) && response.length > 0) extractAndFinish(response[0], fallbackUrl, autoInstall)
            else handleUpError(fallbackUrl, autoInstall, "No " + typeLabel + " found. Using Main.")
        } catch (e) { handleUpError(fallbackUrl, autoInstall, upTr("json_error")) }
    }

    function extractAndFinish(obj, fallbackUrl, autoInstall) {
        var versionTag = obj.tag_name || obj.name || "Unknown"; var foundAsset = ""
        if (obj.assets && obj.assets.length > 0) {
            for (var i = 0; i < obj.assets.length; i++) {
                if (obj.assets[i].name.toLowerCase().endsWith(".zip")) { foundAsset = obj.assets[i].browser_download_url; break }
            }
        }
        if (foundAsset === "") foundAsset = obj.zipball_url
        if (foundAsset) {
            upDetectedVersion = versionTag; upPreparedUrl = foundAsset; upDisplayUrl = foundAsset
            if (!autoInstall) { upStatusText.text = upTr("available") + versionTag; upStatusText.color = "blue" }
            else { upStatusText.text = upTr("found") + versionTag; executeInstallation(foundAsset) }
        } else { handleUpError(fallbackUrl, autoInstall, upTr("no_zip")) }
    }

    function handleUpError(fallbackUrl, autoInstall, msg) {
        upDetectedVersion = "Main (Dev)"; upPreparedUrl = fallbackUrl; upDisplayUrl = fallbackUrl
        if (!autoInstall) { upStatusText.text = msg; upStatusText.color = "#888" }
        else { upStatusText.text = msg; executeInstallation(fallbackUrl) }
    }

    function preCheckVersion() {
        upDetectedVersion = ""; upPreparedUrl = ""; upDisplayUrl = ""; upStatusText.text = ""
        var customUrl = urlField.text.trim()
        if (customUrl !== "") {
            var slug = getRepoSlug(customUrl)
            if (slug !== "") checkGitHubRelease(slug, customUrl, false)
            else { upStatusText.text = upTr("source_direct"); upPreparedUrl = customUrl; upDisplayUrl = customUrl }
            updateTargetDisplay(); return
        }
        if (pluginCombo.currentIndex !== -1) {
            var knownSlug = knownRepositories[upTargetUuid] || knownRepositories[upTargetName]
            if (knownSlug) checkGitHubRelease(knownSlug, "", false)
            else startSmartSearch()
            updateTargetDisplay()
        }
    }

    function updateTargetDisplay() {
        var customUrl = urlField.text.trim()
        if (customUrl !== "") {
            var slug = getRepoSlug(customUrl)
            if (slug !== "") upTargetFolderDisplay = ".../plugins/" + slug.split("/")[1]
            else upTargetFolderDisplay = ".../plugins/CustomPlugin"
        } else if (pluginCombo.currentIndex !== -1) {
            if (upTargetUuid !== "") upTargetFolderDisplay = ".../plugins/" + upTargetUuid
            else upTargetFolderDisplay = ".../plugins/" + upTargetName.replace(/\s+/g, '')
        } else { upTargetFolderDisplay = "..." }
    }

    function startProcess() {
        var customUrl = urlField.text.trim()
        upStatusText.color = "black"; upIsWorking = true; upIsFinished = false
        upProgressBar.value = 0; upProgressBar.indeterminate = true; upIsSelfUpdate = false
        if (upInstalledVersion !== "") upIsSelfUpdate = true
        if (customUrl !== "") {
            var slug = getRepoSlug(customUrl)
            if (slug !== "") checkGitHubRelease(slug, customUrl, true)
            else executeInstallation(customUrl)
            return
        }
        if (pluginCombo.currentIndex !== -1) {
            if (upPreparedUrl !== "") executeInstallation(upPreparedUrl)
            else { upStatusText.text = upTr("wait_search"); upIsWorking = false; upProgressBar.indeterminate = false }
        } else { upStatusText.text = upTr("select_warn"); upStatusText.color = "red"; upIsWorking = false }
    }

    function reloadInstalledPlugin(uuid) {
        if (!uuid || uuid === "") return
        if (pluginManager.isAppPluginEnabled(uuid))
            pluginManager.disableAppPlugin(uuid)
        pluginManager.enableAppPlugin(uuid)
        mainWindow.displayToast(upTr("toast_reloading"))
    }

    function executeInstallation(finalUrl) {
        upFinalDownloadUrl = finalUrl
        installTimer.start()
    }

    // =========================================================================
    // 10. TIMERS — PluginUpdateTool
    // =========================================================================

    Timer {
    id: updateQueueTimer
    interval: 1500; repeat: true
    onTriggered: {
        if (upPluginsQueue.length > 0) {
            var p = upPluginsQueue.shift()
            checkSinglePluginUpdate(p)
        } else {
            updateQueueTimer.stop()
            upIsCheckingUpdates = false
            upUpdatesChecked    = true
            if (upUpdatesResultText.indexOf("Scanning") !== -1 || upUpdatesResultText.indexOf("Scan") !== -1)
                upUpdatesResultText = upTr("status_uptodate")
            // ── Sauvegarde du cache ──────────────────────────────────
            updateCacheSettings.cachedResults = upUpdatesResultText
            updateCacheSettings.cachedAt      = new Date().getTime().toString()
        }
    }
}

    Timer { 
       id: installTimer
       interval: 500
       repeat: false
       onTriggered: pluginManager.installFromUrl(upFinalDownloadUrl) }

    Connections {
        target: pluginManager
        function onInstallProgress(progress) {
            upProgressBar.indeterminate = false; upProgressBar.value = progress; upStatusText.color = "#333"
            var verInfo = upDetectedVersion !== "" ? "(" + upDetectedVersion + ")" : ""
            if (progress < 1) upStatusText.text = upTr("downloading") + " " + verInfo + ": " + Math.round(progress * 100) + "%"
            else upStatusText.text = upTr("extracting")
        }
        function onInstallEnded(uuid, error) {
            upIsWorking = false; upProgressBar.value = 1.0; upProgressBar.indeterminate = false
            if (error && error !== "") { upStatusText.text = upTr("error") + error; upStatusText.color = "red" }
            else {
                upIsFinished = true
                upInstalledUuid = uuid !== "" ? uuid : upTargetUuid
                var successMsg = upTr("plugin_updated")
                if (upDetectedVersion !== "") successMsg += " " + upDetectedVersion
                upStatusText.text  = successMsg
                upStatusText.color = "green"
                if (pluginManager.pluginModel) pluginManager.pluginModel.refresh(false)
                reloadInstalledPlugin(upInstalledUuid)
            }
        }
    }

    // =========================================================================
    // 11. COMPOSANT MARQUEE TEXTFIELD
    // =========================================================================

    component MarqueeTextField : TextField {
        id: mCtrl
        property color normalColor: "black"
        color: activeFocus ? normalColor : "transparent"
        placeholderTextColor: "transparent"
        clip: true
        Layout.preferredHeight: Math.max(40, contentHeight + topPadding + bottomPadding + 14)
        verticalAlignment: TextInput.AlignVCenter
        background: Rectangle {
            color: "transparent"
            border.color: mCtrl.activeFocus ? Theme.mainColor : "#aaa"
            border.width: mCtrl.activeFocus ? 2 : 1
            radius: 4
        }
        Item {
            id: mContainer
            anchors.fill: parent
            anchors.leftMargin:   mCtrl.leftPadding   + 2
            anchors.rightMargin:  mCtrl.rightPadding  + 2
            anchors.topMargin:    mCtrl.topPadding    + 2
            anchors.bottomMargin: mCtrl.bottomPadding + 2
            visible: !mCtrl.activeFocus
            clip: true
            Text {
                id: mScrollText
                text: {
                    if (mCtrl.text === "") return mCtrl.placeholderText
                    if (mCtrl.echoMode === TextInput.Password) return "●".repeat(mCtrl.text.length)
                    return mCtrl.text
                }
                font:  mCtrl.font
                color: mCtrl.text !== "" ? mCtrl.normalColor : "#aaa"
                verticalAlignment: Text.AlignVCenter
                height: parent.height
                width:  implicitWidth
                x: 0
                property bool needsScroll:    width > mContainer.width
                property int  travelDistance: Math.max(0, width - mContainer.width)
                SequentialAnimation on x {
                    running: mScrollText.needsScroll && mContainer.visible
                    loops:   Animation.Infinite
                    PauseAnimation  { duration: 2000 }
                    NumberAnimation { to: -mScrollText.travelDistance; duration: mScrollText.travelDistance > 0 ? mScrollText.travelDistance * 20 : 0; easing.type: Easing.Linear }
                    PauseAnimation  { duration: 1000 }
                    NumberAnimation { to: 0; duration: mScrollText.travelDistance > 0 ? mScrollText.travelDistance * 20 : 0; easing.type: Easing.Linear }
                }
            }
        }
    }

    // =========================================================================
    // 12. DIALOGUE PRINCIPAL
    // =========================================================================

    Dialog {
        id: downloadDialog
        parent: mainWindow.contentItem
        modal:  true

        width:  Math.min(440, mainWindow.width  * 0.94)
        height: Math.min(mainFlickable.contentHeight, mainWindow.height * 0.96)
        x: (parent.width  - width)  / 2
        y: Screen.primaryOrientation === Qt.LandscapeOrientation
            ? Math.max(8, (parent.height - height) / 2)
            : Math.max(8, (parent.height - height) / 2 - 40)

        standardButtons: Dialog.NoButton

        onClosed: {
            // ── GithubDownloader reset ─────────────────────────────
            pluginState    = ""
            destMode       = "project"
            fileTree       = []; repoFolders = []; downloadQueue = []
            baseDestPath   = ""
            ownerCombo.editText     = ""; ownerCombo.currentIndex  = -1
            repoCombo.model         = []; repoCombo.currentIndex   = -1
            repoTextInput.text      = ""; repoInput.text           = ""
            branchInput.text        = "main"; folderInput.text     = ""
            useTokenCheckbox.checked = false; tokenInput.text      = ""
            fileListModel.clear()
            selectAllChk.checked  = false
            radioAll.checked      = true
            statusText.text       = ""; statusText.color = "black"
            infoText.text         = ""
            mainTabBar.currentIndex      = 0
            pluginSubTabBar.currentIndex = 0
            pluginSubTab                 = 0
            mainFlickable.contentY       = 0

            // ── PluginUpdateTool reset ─────────────────────────────
            pluginCombo.currentIndex  = -1
            urlField.text             = ""
            upIsFinished              = false; upIsWorking = false
            upProgressBar.value       = 0
            upStatusText.text         = ""
            upDetectedVersion         = ""; upInstalledVersion   = ""
            upDisplayUrl              = ""; upPreparedUrl        = ""
            upTargetFolderDisplay     = "..."; upTargetUuid      = ""
            upTargetName              = ""; upTargetAuthor       = ""
            upUpdatesChecked          = false
            upUpdatesResultText       = ""
        }

        topPadding:    0; bottomPadding: 0
        leftPadding:   0; rightPadding:  0

        background: Rectangle {
            color: "white"; border.color: Theme.mainColor; border.width: 2; radius: 8
        }

        contentItem: Flickable {
            id:             mainFlickable
            clip:           true
            contentWidth:   width
            contentHeight:  mainCol.y + mainCol.height + 6
            boundsBehavior: Flickable.StopAtBounds

            FocusScope { id: dummyFocus; width: 1; height: 1; z: -1 }

            MouseArea {
                width:  mainFlickable.contentWidth
                height: mainFlickable.contentHeight
                propagateComposedEvents: true
                onClicked: { dummyFocus.forceActiveFocus(); Qt.inputMethod.hide() }
            }

            // ── COLONNE PRINCIPALE ─────────────────────────────────────────
            ColumnLayout {
                id:     mainCol
                x:      10
                y:      6
                width:  mainFlickable.width - 20
                spacing: 4

                // ── TITRE ─────────────────────────────────────────────────
                Label {
                    text:   tr("TITLE")
                    font.bold:       true
                    font.pointSize:  18
                    color:           Theme.mainColor
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 0
                    Layout.bottomMargin: 2
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // ── 1. ONGLETS PRINCIPAUX (Projet / Plugin) ────────────────
                TabBar {
                    id: mainTabBar
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4

                    onCurrentIndexChanged: {
                        destMode = (currentIndex === 1) ? "plugin" : "project"
                        pluginSubTab = 0
                        pluginSubTabBar.currentIndex = 0
                        pluginState = "config"
                        statusText.text = ""; statusText.color = "black"
                        infoText.text = ""
                        fileListModel.clear()
                        if (currentIndex === 0) folderInput.text = ""
                    }

                    // --- ONGLET PROJET ---
                    TabButton {
                        id: btnProject
                        text: "📁  " + tr("CB_DEST_PROJECT")
                        contentItem: Text {
                            text: btnProject.text
                            font.pixelSize: 16
                            font.bold: btnProject.checked
                            color: btnProject.checked ? Theme.mainColor : "#555"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 45
                            color: btnProject.checked ? "#f0f9f0" : "#f8f8f8"  // "#fdfdfd" : "#eeeeee"
                            border.color: btnProject.checked ? Theme.mainColor : "transparent"
                            border.width: btnProject.checked ? 2 : 0
                            radius: 6
                        }
                    }

                    // --- ONGLET PLUGIN ---
                    TabButton {
                        id: btnPlugin
                        text: "🔌  " + tr("CB_DEST_PLUGIN")
                        contentItem: Text {
                            text: btnPlugin.text
                            font.pixelSize: 16
                            font.bold: btnPlugin.checked
                            color: btnPlugin.checked ? Theme.mainColor : "#555"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 45
                            color: btnPlugin.checked ? "#f0f9f0" : "#f8f8f8"  //"#fdfdfd" : "#eeeeee"
                            border.color: btnPlugin.checked ? Theme.mainColor : "transparent"
                            border.width: btnPlugin.checked ? 2 : 0
                            radius: 6
                        }
                    }
                }

                // ── 2. SOUS-ONGLETS PLUGIN (Installer / Mettre à jour) ──────
                TabBar {
                    id: pluginSubTabBar
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    visible: mainTabBar.currentIndex === 1 // Uniquement si onglet Plugin actif

                    onCurrentIndexChanged: {
                        pluginSubTab = currentIndex
                        pluginState = "config"
                        statusText.text = ""; statusText.color = "black"
                        infoText.text = ""
                        fileListModel.clear()
                        if (currentIndex === 1 && !upUpdatesChecked) {
                            upUpdatesResultText = upTr("status_checking")
                            startGlobalUpdateCheck()
                        }
                    }

                    // --- SOUS-ONGLET INSTALLER ---
                    TabButton {
                        id: subBtnInstall
                        text: "⬇  " + upTr("Installer")
                        contentItem: Text {
                            text: subBtnInstall.text
                            font.pixelSize: 13
                            font.bold: subBtnInstall.checked
                            color: subBtnInstall.checked ? Theme.mainColor : "#666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 35
                            color: subBtnInstall.checked ? "#f0f9f0" : "#f8f8f8"
                            border.color: subBtnInstall.checked ? Theme.mainColor : "#ccc"
                            border.width: subBtnInstall.checked ? 1 : 1
                            radius: 4
                        }
                    }

                    // --- SOUS-ONGLET METTRE À JOUR ---
                    TabButton {
                        id: subBtnUpdate
                        text: "🔄  " + upTr("Mettre à jour")
                        contentItem: Text {
                            text: subBtnUpdate.text
                            font.pixelSize: 13
                            font.bold: subBtnUpdate.checked
                            color: subBtnUpdate.checked ? Theme.mainColor : "#666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            implicitHeight: 35
                            color: subBtnUpdate.checked ? "#f0f9f0" : "#f8f8f8"
                            border.color: subBtnUpdate.checked ? Theme.mainColor : "#ccc"
                            border.width: subBtnUpdate.checked ? 1 : 1
                            radius: 4
                        }
                    }
                }

                // ════════════════════════════════════════════════���══════════
                // SECTION FORMULAIRE INSTALL — Projet  OU  Plugin > Installer
                // Masquée quand Plugin > Mettre à jour est actif
                // ═══════════════════════════════════════════════════════════

                ColumnLayout {
                    id: formSection
                    Layout.fillWidth: true
                    spacing: 4
                    visible: !(mainTabBar.currentIndex === 1 && pluginSubTab === 1)

                // ── OWNER + REPO ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // ── OWNER ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 1
                        Text { 
                        text: tr("LBL_OWNER")
                        Layout.bottomMargin: 10
                        color: "#666"
                        font.pixelSize: 11 }

                        ComboBox {
                            id: ownerCombo
                            editable: true
                            currentIndex: -1
                            model: pluginAuthors
                            Layout.fillWidth: false
                            Layout.preferredWidth: 170
                            Layout.bottomMargin: 5
                            Layout.preferredHeight: Math.max(40, implicitContentHeight + topPadding + bottomPadding + 8)
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"

                            onActivated: {
                                if (destMode === "plugin") {
                                    var repos = pluginsByAuthor[currentText.trim()]
                                    repoCombo.model = repos ? repos : []
                                    repoCombo.currentIndex = (repos && repos.length > 0) ? 0 : -1
                                    if (repos && repos.length > 0) folderInput.text = repos[0]
                                }
                            }
                            onEditTextChanged: {
                                if (destMode === "plugin") {
                                    var repos2 = pluginsByAuthor[editText.trim()]
                                    repoCombo.model = repos2 ? repos2 : []
                                    repoCombo.currentIndex = (repos2 && repos2.length > 0) ? 0 : -1
                                    if (repos2 && repos2.length > 0) folderInput.text = repos2[0]
                                }
                            }

                            contentItem: Item {
                                clip: true
                                implicitHeight: 26
                                Item {
                                    id:     ownerClip
                                    clip:   true
                                    anchors.left:           parent.left
                                    anchors.right:          parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin:     8
                                    anchors.rightMargin:    2
                                    height: parent.height - 4

                                    Text {
                                        id:     ownerMarqueeText
                                        x:      0
                                        height: parent.height
                                        visible: !ownerTextInput.activeFocus
                                        text: ownerCombo.editText !== ""
                                            ? ownerCombo.editText : tr("PH_OWNER")
                                        font.pixelSize: 13
                                        color: ownerCombo.editText !== "" ? (ownerCombo.enabled ? "#222" : "#aaa") : "#aaa"
                                        verticalAlignment: Text.AlignVCenter
                                        width: implicitWidth
                                        property bool needsScroll:    implicitWidth > ownerClip.width
                                        property int  travelDistance: Math.max(0, implicitWidth - ownerClip.width)
                                        SequentialAnimation on x {
                                            running:  ownerMarqueeText.needsScroll && ownerCombo.visible && !ownerTextInput.activeFocus
                                            loops:    Animation.Infinite
                                            PauseAnimation  { duration: 2000 }
                                            NumberAnimation { to: -ownerMarqueeText.travelDistance; duration: ownerMarqueeText.travelDistance > 0 ? ownerMarqueeText.travelDistance * 20 : 0; easing.type: Easing.Linear }
                                            PauseAnimation  { duration: 1000 }
                                            NumberAnimation { to: 0; duration: ownerMarqueeText.travelDistance > 0 ? ownerMarqueeText.travelDistance * 20 : 0; easing.type: Easing.Linear }
                                        }
                                        onTextChanged: { x = 0 }
                                    }

                                    TextInput {
                                        id: ownerTextInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 2
                                        color: activeFocus ? "#222" : "transparent"
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        enabled: ownerCombo.editable && ownerCombo.enabled
                                        selectByMouse: true
                                        Component.onCompleted: text = ownerCombo.editText
                                        onTextChanged: ownerCombo.editText = text
                                        onActiveFocusChanged: {
                                            if (activeFocus) { ownerMarqueeText.x = 0; cursorPosition = text.length }
                                        }
                                        cursorDelegate: Rectangle { width: 2; color: "#222"; visible: parent.cursorVisible }
                                    }
                                }
                            }
                        }
                    }

                    // ── REPO ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 1
                        Text { text: tr("LBL_REPO"); color: "#666"; font.pixelSize: 11 }

                        // Mode projet : saisie libre
                        MarqueeTextField {
                            id: repoInput
                            visible: destMode === "project"
                            placeholderText: tr("PH_REPO")
                            selectByMouse: true
                            Layout.fillWidth: true
                            Layout.bottomMargin: 5
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                        }

                        // Mode plugin : liste déroulante
                        ComboBox {
                            id: repoCombo
                            visible: destMode === "plugin"
                            editable: true
                            model: []
                            displayText: editText
                            Layout.preferredWidth: 170
                            Layout.fillWidth: true
                            Layout.topMargin: 9
                            Layout.preferredHeight: Math.max(40, implicitContentHeight + topPadding + bottomPadding + 14)
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                            onEditTextChanged: {
                                if (destMode === "plugin") folderInput.text = editText.trim()
                            }
                            onActivated: {
                                repoTextInput.text = repoCombo.editText
                                repoTextInput.cursorPosition = repoTextInput.text.length
                            }
                            contentItem: Item {
                                clip: true
                                implicitHeight: 26
                                Item {
                                    id:     repoClip
                                    clip:   true
                                    anchors.left:           parent.left
                                    anchors.right:          parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin:     8
                                    anchors.rightMargin:    2
                                    height: parent.height - 4
                                    Text {
                                        id: repoMarqueeText
                                        x:  0
                                        height: parent.height
                                        visible: !repoTextInput.activeFocus
                                        text: repoCombo.editText !== "" ? repoCombo.editText : tr("PH_REPO")
                                        font.pixelSize: 13
                                        color: repoCombo.editText !== "" ? (repoCombo.enabled ? "#222" : "#aaa") : "#aaa"
                                        verticalAlignment: Text.AlignVCenter
                                        width: implicitWidth
                                        property bool needsScroll:    implicitWidth > repoClip.width
                                        property int  travelDistance: Math.max(0, implicitWidth - repoClip.width)
                                        SequentialAnimation on x {
                                            running: repoMarqueeText.needsScroll && repoCombo.visible && !repoTextInput.activeFocus
                                            loops:   Animation.Infinite
                                            PauseAnimation  { duration: 2000 }
                                            NumberAnimation { to: -repoMarqueeText.travelDistance; duration: repoMarqueeText.travelDistance > 0 ? repoMarqueeText.travelDistance * 20 : 0; easing.type: Easing.Linear }
                                            PauseAnimation  { duration: 1000 }
                                            NumberAnimation { to: 0; duration: repoMarqueeText.travelDistance > 0 ? repoMarqueeText.travelDistance * 20 : 0; easing.type: Easing.Linear }
                                        }
                                        onTextChanged: { x = 0 }
                                    }
                                    TextInput {
                                        id: repoTextInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8; anchors.rightMargin: 2
                                        color: activeFocus ? "#222" : "transparent"
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        enabled: repoCombo.editable && repoCombo.enabled
                                        selectByMouse: true
                                        Component.onCompleted: text = repoCombo.editText
                                        onTextChanged: repoCombo.editText = text
                                        onActiveFocusChanged: {
                                            if (activeFocus) { repoMarqueeText.x = 0; cursorPosition = text.length }
                                        }
                                        cursorDelegate: Rectangle { width: 2; color: "#222"; visible: parent.cursorVisible }
                                    }
                                }
                            }
                        }
                    }
                } // RowLayout owner+repo

                // ── BRANCHE + DOSSIER LOCAL ─────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ColumnLayout {
                        Layout.preferredWidth: 110
                        spacing: 1
                        Text { text: tr("LBL_BRANCH"); color: "#666"; font.pixelSize: 11 }
                        MarqueeTextField {
                            id: branchInput
                            text: "main"
                            placeholderText: tr("PH_BRANCH")
                            selectByMouse:   true
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: destMode === "plugin" ? tr("LBL_FOLDER_PLUGIN") : tr("LBL_FOLDER"); color: "#666"; font.pixelSize: 11 }
                        MarqueeTextField {
                            id: folderInput
                            placeholderText: tr("PH_FOLDER")
                            selectByMouse:   true
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhNoPredictiveText
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                        }
                    }
                }

                // ── TOKEN CHECKBOX ─────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    CheckBox {
                        id: useTokenCheckbox
                        checked: false
                        enabled: pluginState !== "exploring" && pluginState !== "downloading"
                    }
                    Text {
                        text:    tr("CB_TOKEN")
                        color:   "#333"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { if (useTokenCheckbox.enabled) useTokenCheckbox.checked = !useTokenCheckbox.checked }
                        }
                    }
                }

                MarqueeTextField {
                    id: tokenInput
                    visible: useTokenCheckbox.checked
                    placeholderText: tr("PH_TOKEN")
                    echoMode:  activeFocus ? TextInput.Normal : TextInput.Password
                    selectByMouse: true
                    Layout.fillWidth: true
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                                    | Qt.ImhSensitiveData | Qt.ImhNoAutoCorrect
                    enabled: pluginState !== "exploring" && pluginState !== "downloading"
                }

                // ── BOUTON EXPLORER ────────────────────────────────────────
                Button {
                    id:   exploreBtn
                    text: (pluginState === "exploring") ? tr("BTN_EXPLORING") : tr("BTN_EXPLORE")
                    enabled: pluginState !== "exploring" && pluginState !== "downloading"
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    background: Rectangle { color: exploreBtn.enabled ? Theme.mainColor : "#aaa"; radius: 6 }
                    contentItem: Text {
                        text: parent.text; color: "white"
                        font.bold: true; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: startExplore()
                }

                // ═══════════════════════════════════════════════════════════
                // RÉSULTATS EXPLORATION (partagé Projet et mode Install Plugin)
                // ═══════════════════════════════════════════════════════════

                ColumnLayout {
                    visible: pluginState === "ready" || pluginState === "downloading" || pluginState === "done"
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: tr("LBL_FILES_FOUND") + "  " + fileTree.length
                        font.bold: true; font.pixelSize: 13; color: "#222"
                    }
                    RowLayout {
                        spacing: 4
                        Text { text: tr("LBL_DEST"); color: "#888"; font.pixelSize: 11 }
                        Text {
                            text: baseDestPath; font.bold: true; font.pixelSize: 11; color: "#333"
                            elide: Text.ElideLeft; Layout.fillWidth: true
                        }
                    }
                }

                ButtonGroup { id: dlModeGroup }

                ColumnLayout {
                    visible: pluginState === "ready" || pluginState === "done"
                    Layout.fillWidth: true
                    spacing: 0; Layout.topMargin: 2
                    RadioButton { id: radioAll;    text: tr("RADIO_ALL");    checked: true;  ButtonGroup.group: dlModeGroup; enabled: pluginState !== "downloading" }
                    RadioButton { id: radioCustom; text: tr("RADIO_CUSTOM"); checked: false; ButtonGroup.group: dlModeGroup; enabled: pluginState !== "downloading" }
                }

                Column {
                    id: fileListSection
                    visible: (pluginState === "ready" || pluginState === "done") && radioCustom.checked
                    width:   mainCol.width
                    spacing: 0
                    Layout.preferredHeight: implicitHeight
                    Layout.fillWidth: true
                    Layout.topMargin: 2

                    Rectangle {
                        width: parent.width; height: 42; color: Theme.mainColor; radius: 3
                        Row {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 4
                            CheckBox {
                                id: selectAllChk
                                anchors.verticalCenter: parent.verticalCenter
                                checked: false
                                onClicked: {
                                    for (var i = 0; i < fileListModel.count; i++)
                                        fileListModel.setProperty(i, "isSelected", checked)
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tr("LBL_SEL_ALL"); color: "white"; font.bold: true; font.pixelSize: 12
                                width: parent.width - selectAllChk.width - 12
                                verticalAlignment: Text.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectAllChk.checked = !selectAllChk.checked
                                        for (var i = 0; i < fileListModel.count; i++)
                                            fileListModel.setProperty(i, "isSelected", selectAllChk.checked)
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: fileListModel
                        delegate: Item {
                            width:  fileListSection.width
                            height: model.visible ? (model.nodeType === "folder" ? 44 : 40) : 0
                            clip:   true

                            Rectangle {
                                visible: model.nodeType === "folder" && model.visible
                                width: parent.width; height: 44
                                color: Qt.rgba(Theme.mainColor.r, Theme.mainColor.g, Theme.mainColor.b, 0.10)
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(Theme.mainColor.r, Theme.mainColor.g, Theme.mainColor.b, 0.30) }
                                MouseArea {
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: 48
                                    onClicked: ghDownloader.toggleFolder(model.nodeKey)
                                }
                                Item {
                                    x: 6 + model.depth * 14; y: 0
                                    width: parent.width - x - 6; height: parent.height
                                    RowLayout {
                                        anchors.fill: parent; anchors.rightMargin: 2; spacing: 4
                                        Text { text: model.expanded ? "▼" : ">"; font.pixelSize: 14; color: "#000000"; Layout.preferredWidth: 14; verticalAlignment: Text.AlignVCenter }
                                        Text { text: model.expanded ? "📂" : "📁"; font.pixelSize: 22 }
                                        Text { text: model.displayName; font.bold: true; font.pixelSize: 13; color: "#1a1a2e"; elide: Text.ElideRight; Layout.fillWidth: true }
                                        CheckBox { checked: model.isSelected; onClicked: ghDownloader.setFolderSelected(model.nodeKey, checked) }
                                    }
                                }
                            }

                            Rectangle {
                                visible: model.nodeType === "file" && model.visible
                                width: parent.width; height: 40
                                color: (index % 2 === 0) ? "white" : "#f8f8f8"
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#ececec" }
                                Item {
                                    x: 6 + model.depth * 14; y: 0
                                    width: parent.width - x - 6; height: parent.height
                                    RowLayout {
                                        anchors.fill: parent; anchors.rightMargin: 2; spacing: 2
                                        Text { text: "└"; font.pixelSize: 11; color: "#ccc"; Layout.preferredWidth: 12 }
                                        CheckBox { checked: model.isSelected; onClicked: fileListModel.setProperty(index, "isSelected", checked) }
                                        Text {
                                            text: {
                                                var n = model.displayName.toLowerCase()
                                                if (n.endsWith(".gpkg")) return "🗄"
                                                if (n.endsWith(".qgz") || n.endsWith(".qgs")) return "🗺"
                                                if (n.endsWith(".qml")) return "📝"
                                                if (n.endsWith(".svg")) return "🎨"
                                                if (n.endsWith(".pdf")) return "📄"
                                                if (n.endsWith(".csv")) return "📊"
                                                return "📎"
                                            }
                                            font.pixelSize: 13
                                        }
                                        Text { text: model.displayName; font.pixelSize: 12; color: "#222"; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: model.sizeLabel; font.pixelSize: 11; color: "#aaa"; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                                    }
                                }
                            }
                        }
                    }
                } // Column fileListSection

                ProgressBar {
                    Layout.fillWidth: true
                    visible: pluginState === "downloading"
                    value: totalFiles > 0 ? processedFiles / totalFiles : 0
                    Layout.topMargin: 4
                }

                Text {
                    id:             statusText
                    text:           ""
                    font.bold:      true; font.pixelSize: 12
                    wrapMode:       Text.WordWrap; Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible:        text.length > 0; Layout.topMargin: 2
                }

                Text {
                    id:             infoText
                    text:           ""
                    font.pixelSize: 11; color: "#555"
                    wrapMode:       Text.WordWrap; Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible:        text.length > 0
                    elide:          Text.ElideLeft
                }

                // ── BOUTONS D'ACTION ───────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 2; spacing: 4

                    Item { 
                     Layout.fillWidth: true
                     height: 36
                     visible: pluginState === "ready"
                        Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                            Button { 
height: 36
text: tr("BTN_DOWNLOAD")
background: Rectangle { color: Theme.mainColor
radius: 6 }
 contentItem: Text { text: parent.text
 color: "white"
font.bold: true
 font.pixelSize: 12
 horizontalAlignment: Text.AlignHCenter
 verticalAlignment: Text.AlignVCenter }
 onClicked: startDownload() }
                            Button { 
height: 36
 text: tr("BTN_CLOSE")
background: Rectangle { 
color: "#888"
 radius: 6 }
 contentItem: Text { text: parent.text
 color: "white"
 font.bold: true
font.pixelSize: 12
 horizontalAlignment: Text.AlignHCenter
 verticalAlignment: Text.AlignVCenter }
 onClicked: 
downloadDialog.close() }
                        }
                    }

                    Item { 
                     Layout.fillWidth: true
                     height: 36
                     visible: pluginState === "config" || pluginState === "exploring"
                        Row { anchors.horizontalCenter: parent.horizontalCenter
                            Button {
                            height: 36
                            text: tr("BTN_CLOSE")
                           background: Rectangle { color: "#888"
 radius: 6 }
                           contentItem: Text { 
                           text: parent.text
                           color: "white"
                           font.bold: true
                           font.pixelSize: 12
                           horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter }
 onClicked: downloadDialog.close() }
                        }
                    }

                    Item { 
                       Layout.fillWidth: true
                       height: 36
                       visible: pluginState === "done" && destMode === "project"
                        Row { 
                         anchors.horizontalCenter: parent.horizontalCenter
                         spacing: 8
                            Button { 
                            height: 36 
                            text: tr("BTN_UPDATE") 
                            background: 
                           Rectangle { 
                            color: Theme.mainColor
                            radius: 6 }

                            contentItem: Text { 
                            text: parent.text
                            color: "white"
                            font.bold: true
                            font.pixelSize: 12  
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter }
                               onClicked: { 
                               pluginState = "ready"
                               radioCustom.checked = true
                               statusText.text = ""
                              infoText.text = ""
                              selectAllChk.checked = false
 for (var i = 0; i < fileListModel.count; i++) fileListModel.setProperty(i, "isSelected", false) }
                            }
                            Button { 
                              height: 36
                              text: tr("BTN_OPEN")
                              background: 
                              Rectangle { 
                              color: "#80cc28"
                              radius: 6 }

                               contentItem: Text { 
                                text: parent.text
                                color: "white"
                                font.bold: true
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                 verticalAlignment: Text.AlignVCenter }
                                onClicked: { 
                                var projPath = findRootProjectFile()
                                 downloadDialog.close()
 if (projPath !== "") iface.loadFile(projPath) }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; height: 36; visible: pluginState === "done"
                        Row { anchors.horizontalCenter: parent.horizontalCenter
                            Button { 
                             height: 36
                             text: tr("BTN_CLOSE")
                             background:
                             Rectangle { 
                             color: "#888"
                             radius: 6 }

                               contentItem: Text { 
                               text: parent.text
                               color: "white"
                               font.bold: true
                               font.pixelSize: 12
                               horizontalAlignment: Text.AlignHCenter
                               verticalAlignment: Text.AlignVCenter }
                               onClicked: downloadDialog.close() }
                        }
                    }
                }

                } // ── fin formSection ─────────────────────────────────────

                // ═══════════════════════════════════════════════════════════
                // SECTION MISE À JOUR — PluginUpdateTool
                // Visible uniquement dans Plugin > sous-onglet Mettre à jour
                // ═══════════════════════════════════════════════════════════

                ColumnLayout {
                    id: updateSection
                    Layout.fillWidth: true
                    spacing: 4
                    visible: mainTabBar.currentIndex === 1 && pluginSubTab === 1

             //   Rectangle {
                  //  Layout.fillWidth: true
                 //   Layout.topMargin: 8; Layout.bottomMargin: 2
                  //  height: 2
                 //   color: Theme.mainColor
                  //  opacity: 0.4
              //  }

                Label {
    text: upTr("up_title")
    color: "black"; font.bold: true; font.pointSize: 13
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 0; Layout.bottomMargin: 6
}

                // ── Sélection du plugin installé ──────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    ComboBox {
                        id: pluginCombo
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        font.pixelSize: 14
                        textRole: "name"; model: pluginManager.availableAppPlugins
                        displayText: currentIndex === -1 ? upTr("select_placeholder") : currentText
                        onActivated: {
                            urlField.text = ""
                            var plugins = pluginManager.availableAppPlugins
                            if (index >= 0 && index < plugins.length) {
                                var p = plugins[index]
                                upInstalledVersion = p.version
                                upTargetName       = p.name
                                upTargetUuid       = p.uuid
                                upTargetAuthor     = (p.author !== undefined) ? p.author : ""
                            } else {
                                upInstalledVersion = ""; upTargetName = ""; upTargetUuid = ""; upTargetAuthor = ""
                            }
                            upDisplayUrl = ""; upPreparedUrl = ""
                            preCheckVersion()
                        }
                    }
                    Button {
                        text: "✖"; visible: pluginCombo.currentIndex !== -1
                        Layout.preferredWidth: 40; Layout.preferredHeight: 34
                        onClicked: {
                            pluginCombo.currentIndex = -1; upStatusText.text = ""
                            upDetectedVersion = ""; upInstalledVersion = ""
                            upDisplayUrl = ""; updateTargetDisplay()
                        }
                    }
                }

                // URL affichée (lecture seule)
                TextField {
                    visible: upDisplayUrl !== ""
                    Layout.fillWidth: true; text: upDisplayUrl; readOnly: true; selectByMouse: true
                    font.pixelSize: 12; color: "#555"
                    background: Rectangle { color: "#f0f0f0"; radius: 4 }
                    Layout.preferredHeight: 34; verticalAlignment: TextInput.AlignVCenter
                }

                Label {
                    text: upTr("or_custom"); font.bold: true; font.pixelSize: 13; Layout.topMargin: 2
                }

                TextField {
                    id: urlField
                    Layout.fillWidth: true; Layout.preferredHeight: 34
                    placeholderText: "https://github.com/user/repo"
                    selectByMouse: true; font.pixelSize: 14
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: {
                        pluginCombo.currentIndex  = -1; upInstalledVersion = ""; upDisplayUrl = ""
                        if (text.length > 10) preCheckVersion(); else updateTargetDisplay()
                    }
                }

                Label {
                    text: upTr("destination"); font.bold: true; font.pixelSize: 13; Layout.topMargin: 2
                }

                Rectangle {
                    Layout.fillWidth: true;  Layout.preferredHeight: 32
                    color: "#e0e0e0"; radius: 4; border.color: "#999"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
                        Text { text: "📂"; font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
                        Text { text: upTargetFolderDisplay; font.family: "Courier"; font.pixelSize: 13; color: "#333"; elide: Text.ElideMiddle; Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter }
                    }
                }

                ProgressBar {
                    id: upProgressBar
                    visible: upIsWorking || upIsFinished
                    Layout.fillWidth: true; Layout.topMargin: 2; Layout.preferredHeight: 8
                    from: 0; to: 1.0; value: 0
                    indeterminate: upIsWorking && value === 0
                }

                Text {
                    visible: upInstalledVersion !== ""
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 14; color: "black"
                    text: upTr("installed_ver") + upInstalledVersion
                }

                Text {
                    id: upStatusText
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    font.italic: true; font.pixelSize: 14
                    font.weight: upDetectedVersion !== "" ? Font.Bold : Font.Normal
                    color: "#555"; wrapMode: Text.Wrap; text: ""
                }

                // Zone de résultats du scan global
             // Bouton rafraîchir la liste de mises à jour
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: upStatusText.text !== "" ? 4 : -18;  Layout.bottomMargin: 2
                    leftPadding: 16; rightPadding: 16
                    visible: !upIsCheckingUpdates
                    background: Rectangle { color: Theme.mainColor; radius: 4 }
                    contentItem: Text {
                        text: upTr("Refresh the list of plugins to update")
                        color: "white"; font.bold: true; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        updateCacheSettings.cachedAt = "0"
                        upUpdatesChecked = false
                        upUpdatesResultText = ""
                        startGlobalUpdateCheck()
                    }
                }
                TextArea {
                    Layout.fillWidth: true; Layout.topMargin: 2
                    Layout.preferredHeight: Math.max(34, contentHeight + 4)
                    readOnly: true; text: upUpdatesResultText
                    color: "#333"; font.pixelSize: 13
                    background: Rectangle { color: "#f9f9f9"; radius: 4; border.color: "#ddd" }
                    leftPadding: 4; rightPadding: 4; topPadding: 4; bottomPadding: 4
                }

                // Bouton Installer / Mettre à jour
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 5; Layout.bottomMargin: 8
                    leftPadding: 20; rightPadding: 20
                    enabled: !upIsWorking && (pluginCombo.currentIndex !== -1 || urlField.text !== "")
                    background: Rectangle { color: parent.enabled ? Theme.mainColor : "#bdc3c7"; radius: 4 }
                    contentItem: Text {
                        text: upIsWorking ? upTr("btn_wait") : (upInstalledVersion !== "" ? upTr("btn_update") : upTr("btn_install"))
                        color: "white"; font.bold: true; font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: startProcess()
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    leftPadding: 20; rightPadding: 20
                    visible: upIsFinished && upInstalledUuid !== ""
                    background: Rectangle { color: "#2980b9"; radius: 4 }
                    contentItem: Text {
                        text: upTr("btn_reload")
                        color: "white"; font.bold: true; font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: reloadInstalledPlugin(upInstalledUuid)
                }


                } // ── fin updateSection ────────────────────────────────────

            } // ColumnLayout mainCol
        } // Flickable
    } // Dialog

} // Item ghDownloader

