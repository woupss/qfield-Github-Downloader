import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme
import org.qfield
import org.qgis
import QtCore

// =============================================================================
// GithubProjectDownloader.qml
// Plugin QField autonome — Téléchargeur de projet GitHub complet
//
// Phase 1 : saisie owner / repo / branche / dossier / token optionnel
// Phase 2 : exploration via API GitHub git/trees (récursive)
// Phase 3 : liste checkable de tous les fichiers/dossiers du repo
// Phase 4 : téléchargement séquentiel (LFS + magic-bytes GPKG + swap atomique)
// Phase 5 : mise à jour sélective sans ré-explorer
// =============================================================================

Item {
    id: ghDownloader
    property var mainWindow: iface.mainWindow()

    // =========================================================================
    // 0. BOUTON DANS LA TOOLBAR QFIELD
    // =========================================================================

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(toolBtn)
    }

    QfToolButton {
        id:        toolBtn
        iconSource: 'icon.png'
        iconColor:  Theme.mainColor
        bgcolor:    Theme.darkGray
        round:      true
        onClicked:  ghDownloader.openUI()
    }

        // =========================================================================
    // 1. INTERFACE PUBLIQUE
    // =========================================================================

    function openUI() {
        // Préserve les champs de saisie entre ouvertures du dialogue
        statusText.text  = ""
        statusText.color = "black"
        infoText.text    = ""
        if (pluginState === "") pluginState = "config"
        downloadDialog.open()
    }

    // =========================================================================
    // 2. ÉTAT INTERNE
    // =========================================================================

    // "config"      → formulaire vierge, attend l'exploration
    // "exploring"   → appel API tree en cours
    // "ready"       → arbre récupéré, prêt à télécharger
    // "downloading" → file de téléchargement active
    // "done"        → téléchargement terminé avec succès

    property string pluginState:    ""
    property var    fileTree:       []   // [{path, folder, filename, size}]
    property var    repoFolders:    []   // tous les chemins de dossiers du repo
    property var    downloadQueue:  []
    property int    totalFiles:     0
    property int    processedFiles: 0
    property string baseDestPath:   ""  // chemin absolu du dossier projet local
    property string destMode:       "project"  // "project" | "plugin"

    // ── Données connues pour le mode Plugin ────────────────────────────

    property var pluginAuthors: ["woupss", "coastalrocket", "danielseisenbacher", "FeelGood-GeoSolutions", "gacarrillor", "HeatherHillers", "mbernasocchi", "opengisch", "paul-carteron", "TyHol"]


    property var pluginsByAuthor: ({
        "woupss":        ["qfield-pluginbox", "qfield-filter-plugin", "qfield-DriveMe", "qfield-plugin-update", "qfield-github-downloader", "qfield-theme-position-color"],
        "gacarrillor": 
["qfield-plugin-reloader"],
        "HeatherHillers":["qfield_vegetation_monitoring"],
        "TyHol": 
["DeleteViaDropdown", "Conversion_tools", "KMRT_Plugin", "Qfield_search_Irish_UK_Grid"],
        "danielseisenbacher": 
["qfield-image-based-feature-creation", "TrackedFeatureMarker"],
        "paul-carteron": 
["qfield-quicke", "qfield-cubexp"],
        "coastalrocket": 
["quick_capture", "qfield-osnamesapi-locator"],
        "FeelGood-GeoSolutions": 
["FeelGood-OneTapMeasurement", "FeelGood-UITweaker"],
       "mbernasocchi": 
["qfield-layer-loader", "qfield-ask-ai"],
     "opengisch": 
["qfield-geometryless-addition"]
    })

    // =========================================================================
    // 3. TRADUCTIONS FR / EN
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
    // 4. HELPERS — ACCÈS AUX CHAMPS
    // =========================================================================

    function getOwner()  {
        return ownerCombo.editText.trim()
    }
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

    // =========================================================================
    // 5. HELPERS — CONSTRUCTION D'URLs
    // =========================================================================

    // URL de téléchargement d'un fichier via l'API Contents
    function buildDownloadUrl(filePath) {
        var encodedPath = filePath.split("/")
            .map(function(s) { return encodeURIComponent(s) })
            .join("/")
        return "https://api.github.com/repos/"
            + getOwner() + "/" + getRepo()
            + "/contents/" + encodedPath
            + "?ref=" + getBranch()
    }

    // Endpoint LFS batch pour les blobs Git-LFS
    function getRepoLfsUrl() {
        return "https://github.com/"
            + getOwner() + "/" + getRepo()
            + ".git/info/lfs/objects/batch"
    }

    // Chemin absolu du dossier projet dans le stockage QField Android.
    //
    // platformUtilities.applicationDirectory() retourne le dossier racine
    // QField (ex: …/ch.opengis.qfield_dev/files/Imported Projects)
    // quelle que soit la variante du package — sans aucun hardcoding.
    function computeBaseDestPath() {
        var folder = getFolder()
        if (folder === "") folder = "projet_github"

        var appDir = platformUtilities.applicationDirectory()
    //    iface.logMessage("[GHD][PATH] applicationDirectory : " + appDir)
      //  iface.logMessage("[GHD][PATH] destMode : " + destMode)

        if (appDir && appDir !== "") {
            var appDirLower = appDir.toLowerCase()

            if (destMode === "plugin") {
                // Plugin : chemin → …/files/QField/plugins/<folder>
                // applicationDirectory retourne …/files/Imported Projects ou …/files
                // On remonte jusqu'à /files/ pour construire le chemin plugins
                var filesBase = appDir
                if (appDirLower.indexOf("imported projects") !== -1
                        || appDirLower.indexOf("imported_projects") !== -1) {
                    // Supprimer le dernier segment "Imported Projects"
                    filesBase = appDir.substring(0, appDir.lastIndexOf("/"))
                }
                var base = filesBase + "/QField/plugins/" + folder
            //    iface.logMessage("[GHD][PATH] baseDestPath (plugin) : " + base)
                return base
            }

            // Mode "project" (défaut) : …/files/Imported Projects/<folder>
            var importedDir = appDir
            if (appDirLower.indexOf("imported projects") === -1
                    && appDirLower.indexOf("imported_projects") === -1) {
                importedDir = appDir + "/Imported Projects"
            //    iface.logMessage("[GHD][PATH] ajout Imported Projects : " + importedDir)
            }
            var base2 = importedDir + "/" + folder
         //   iface.logMessage("[GHD][PATH] baseDestPath (project) : " + base2)
            return base2
        }

        // Fallback depuis homePath
        var root = qgisProject.homePath ? qgisProject.homePath.toString() : ""
        if (root.indexOf("file://") === 0) root = root.substring(7)
        root = decodeURIComponent(root)
      //  iface.logMessage("[GHD][PATH] fallback homePath : " + root)
        var markers = ["/Imported Projects/", "/imported_projects/"]
        for (var m = 0; m < markers.length; m++) {
            var markerIdx = root.indexOf(markers[m])
            if (markerIdx >= 0) {
                if (destMode === "plugin") {
                    var filesBase2 = root.substring(0, markerIdx)
                    var base3 = filesBase2 + "/QField/plugins/" + folder
                //    iface.logMessage("[GHD][PATH] fallback plugin : " + base3)
                    return base3
                }
                var base4 = root.substring(0, markerIdx) + markers[m] + folder
            //    iface.logMessage("[GHD][PATH] fallback project : " + base4)
                return base4
            }
        }

     //   iface.logMessage("[GHD][PATH] FALLBACK absolu")
        if (destMode === "plugin")
            return "/storage/emulated/0/Android/data/ch.opengis.qfield_dev/files/QField/plugins/" + folder
        return "/storage/emulated/0/Android/data/ch.opengis.qfield_dev/files/Imported Projects/" + folder
    }

    // Chemin absolu d'un fichier individuel dans le projet local
    function buildDestPath(subFolder, fileName) {
        var p = baseDestPath
        if (subFolder && subFolder !== "") p = p + "/" + subFolder
        return p + "/" + fileName
    }

    // Formate une taille en octets en Ko / Mo lisible
    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " " + tr("LBL_KB")
        return (bytes / (1024 * 1024)).toFixed(1) + " " + tr("LBL_MB")
    }

    // =========================================================================
    // 6. PHASE EXPLORATION — 2 étapes pour garantir l'arbre récursif complet
    //
    // Problème : git/trees/{branchName}?recursive=1 ne retourne parfois que
    // l'arbre de premier niveau car GitHub résout le nom de branche vers le
    // COMMIT, pas vers le TREE. La solution fiable est :
    //   Étape 1 → GET /branches/{branch}  pour obtenir commit.commit.tree.sha
    //   Étape 2 → GET /git/trees/{treeSha}?recursive=1  (SHA exact du tree)
    // =========================================================================

    function startExplore() {
        // Forcer la perte de focus → valide les champs + cache le clavier virtuel
        dummyFocus.forceActiveFocus()
        Qt.inputMethod.hide()

        // En mode plugin, folderInput sera auto-rempli depuis repoInput
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

        // ── Étape 1 : résoudre la branche → obtenir le SHA du tree racine ──
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
                    // Le SHA du tree est dans commit.commit.tree.sha
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

    // ── Étape 2 : fetcher l'arbre récursif complet avec le SHA exact du tree ──
    function fetchTreeBySha(treeSha) {
        var treeUrl = "https://api.github.com/repos/"
            + getOwner() + "/" + getRepo()
            + "/git/trees/" + treeSha
            + "?recursive=1"

        var xhr = new XMLHttpRequest()
        xhr.open("GET", treeUrl)
        xhr.setRequestHeader("Accept", "application/vnd.github.v3+json")
        var tkn = getToken()
        if (tkn !== "") xhr.setRequestHeader("Authorization", "Bearer " + tkn)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    processTree(JSON.parse(xhr.responseText))
                } catch(e) {
                    setConfigError(tr("ERR_TREE") + " (" + e + ")")
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

    // Traite la réponse JSON de l'API tree :
    //   1. Peuple fileTree (source de vérité des blobs)
    //   2. Délègue à buildTreeModel() pour construire le modèle d'affichage
    function processTree(data) {
        var blobs = []
        var folders = []   // dossiers explicites du repo (type "tree")
        if (data.tree) {
            for (var i = 0; i < data.tree.length; i++) {
                var item = data.tree[i]

                // Ignorer les entrées .git pour tous types
                var isGitMeta = item.path.split("/").some(function(seg) {
                    return seg === ".git" || seg.indexOf(".git") === 0
                })
                if (isGitMeta) continue

                if (item.type === "tree") {
                    // Collecter les dossiers natifs du repo (indépendamment des fichiers)
                    folders.push(item.path)
                    continue
                }
                if (item.type !== "blob") continue

                var parts     = item.path.split("/")
                var fname     = parts[parts.length - 1]
                var subfolder = (parts.length > 1)
                    ? parts.slice(0, parts.length - 1).join("/")
                    : ""
                blobs.push({ path: item.path, folder: subfolder,
                             filename: fname, size: item.size || 0 })
            }
        }
        fileTree    = blobs
        repoFolders = folders   // stocké pour buildTreeModel
       // iface.logMessage("[GHD][TREE] blobs trouvés : " + blobs.length)

        buildTreeModel()

        selectAllChk.checked = false
        baseDestPath = computeBaseDestPath()

        var truncated    = (data.truncated === true)
        pluginState      = "ready"
        statusText.text  = truncated ? tr("ERR_TRUNCATED") : ""
        statusText.color = truncated ? "#e67e22" : "black"
        infoText.text    = ""
        radioAll.checked = true
    }

    // ─────────────────────────────────────────────────────────────────────
    // buildTreeModel — construit fileListModel en arborescence
    //
    // Chaque nœud du modèle a les propriétés :
    //   nodeType    : "folder" | "file"
    //   displayName : nom affiché (dernier segment du chemin)
    //   nodeKey     : chemin complet dans le repo (clé unique)
    //   parentKey   : chemin du dossier parent ("" = racine)
    //   depth       : niveau de profondeur (0 = racine)
    //   expanded    : dossier ouvert ou fermé
    //   visible     : affiché ou masqué (enfants masqués par défaut)
    //   isSelected  : cochée (fichiers) / tous enfants cochés (dossiers)
    //   idx         : index dans fileTree (-1 pour les dossiers)
    //   sizeLabel   : taille formatée (fichiers uniquement)
    // ─────────────────────────────────────────────────────────────────────
    function buildTreeModel() {
        fileListModel.clear()

        // ── 1. Collecter tous les dossiers uniques ─────────────────────
        // On utilise repoFolders (entrées "tree" de l'API GitHub) pour avoir
        // TOUS les dossiers du repo, y compris ceux dont tous les blobs ont
        // été filtrés (ex: dossier ne contenant que .gitkeep).
        var folderSet      = {}   // path → true
        var folderChildren = {}   // path → { folders: [], fileIdxs: [] }

        folderSet[""] = true
        folderChildren[""] = { folders: [], fileIdxs: [] }

        // D'abord les dossiers natifs du repo (source de vérité)
        for (var ri = 0; ri < repoFolders.length; ri++) {
            var rf = repoFolders[ri]
            if (!folderSet[rf]) {
                folderSet[rf]      = true
                folderChildren[rf] = { folders: [], fileIdxs: [] }
            }
        }

        // Puis les dossiers déduits des blobs non filtrés (déjà inclus normalement)
        for (var i = 0; i < fileTree.length; i++) {
            var f = fileTree[i].folder
            if (f !== "" && !folderSet[f]) {
                folderSet[f]      = true
                folderChildren[f] = { folders: [], fileIdxs: [] }
            }
        }

        // ── 2. Construire les relations parent → enfant dossiers ───────
        var allFolders = []
        for (var fk in folderSet) { if (fk !== "") allFolders.push(fk) }
        allFolders.sort()

        for (var ai = 0; ai < allFolders.length; ai++) {
            var fp    = allFolders[ai]
            var parts = fp.split("/")
            var par   = parts.length > 1 ? parts.slice(0, -1).join("/") : ""
            if (!folderChildren[par]) folderChildren[par] = { folders: [], fileIdxs: [] }
            if (folderChildren[par].folders.indexOf(fp) === -1)
                folderChildren[par].folders.push(fp)
        }

        // ── 3. Affecter les fichiers à leur dossier parent ─────────────
        for (var bi = 0; bi < fileTree.length; bi++) {
            var pf = fileTree[bi].folder
            if (!folderChildren[pf]) folderChildren[pf] = { folders: [], fileIdxs: [] }
            folderChildren[pf].fileIdxs.push(bi)
        }

        // ── 4. Trier les fichiers de chaque dossier par nom ───────────
        for (var sk in folderChildren) {
            folderChildren[sk].folders.sort()
            folderChildren[sk].fileIdxs.sort(function(a, b) {
                return fileTree[a].filename.localeCompare(fileTree[b].filename)
            })
        }

        // ── 5. Parcours récursif depth-first pour peupler fileListModel
        function addNodes(parentKey, depth) {
            var ch = folderChildren[parentKey]
            if (!ch) return
            var vis = (depth === 0)   // seuls les nœuds racine sont visibles au départ

            // Sous-dossiers d'abord
            for (var fi = 0; fi < ch.folders.length; fi++) {
                var fp2   = ch.folders[fi]
                var fName = fp2.split("/").slice(-1)[0]
                fileListModel.append({
                    nodeType: "folder", displayName: fName,
                    nodeKey: fp2, parentKey: parentKey,
                    depth: depth, expanded: false, visible: vis,
                    isSelected: false, idx: -1, sizeLabel: ""
                })
                addNodes(fp2, depth + 1)
            }

            // Fichiers ensuite
            for (var gi = 0; gi < ch.fileIdxs.length; gi++) {
                var bIdx = ch.fileIdxs[gi]
                var blob = fileTree[bIdx]
                fileListModel.append({
                    nodeType: "file", displayName: blob.filename,
                    nodeKey: blob.path, parentKey: parentKey,
                    depth: depth, expanded: false, visible: vis,
                    isSelected: false, idx: bIdx,
                    sizeLabel: formatSize(blob.size)
                })
            }
        }

        addNodes("", 0)
     //   iface.logMessage("[GHD][TREE] nœuds modèle : " + fileListModel.count)
    }

    // Ouvre ou ferme un dossier (toggle)
    function toggleFolder(nodeKey) {
        var folderIdx = -1
        for (var i = 0; i < fileListModel.count; i++) {
            var n = fileListModel.get(i)
            if (n.nodeType === "folder" && n.nodeKey === nodeKey) {
                folderIdx = i; break
            }
        }
        if (folderIdx === -1) return

        var wasExpanded = fileListModel.get(folderIdx).expanded
        fileListModel.setProperty(folderIdx, "expanded", !wasExpanded)
    //    iface.logMessage("[GHD][TREE] toggleFolder " + nodeKey + " expanded=" + !wasExpanded)

        if (!wasExpanded) {
            // Ouvrir : rendre visibles les enfants directs
            for (var j = 0; j < fileListModel.count; j++) {
                if (fileListModel.get(j).parentKey === nodeKey)
                    fileListModel.setProperty(j, "visible", true)
            }
        } else {
            // Fermer : masquer tous les descendants récursivement
            hideDescendants(nodeKey)
        }
    }

    // Masque récursivement tous les descendants d'un dossier
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

    // Coche/décoche tous les fichiers ET sous-dossiers descendants d'un dossier.
    // Les sous-dossiers reçoivent aussi isSelected pour que leur checkbox reflète l'état.
    function setFolderSelected(nodeKey, selected) {
      //  iface.logMessage("[GHD][TREE] setFolderSelected " + nodeKey + " → " + selected)
        var prefix = nodeKey + "/"
        for (var i = 0; i < fileListModel.count; i++) {
            var nd = fileListModel.get(i)
            if (nd.nodeKey.indexOf(prefix) === 0)
                // Fichiers ET sous-dossiers sont cochés/décochés
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
    // 7. MODÈLE DE LA LISTE CHECKABLE
    // =========================================================================

    ListModel { id: fileListModel }

    // =========================================================================
    // 8. PHASE TÉLÉCHARGEMENT
    // =========================================================================

    function startDownload() {
        dummyFocus.forceActiveFocus()
        Qt.inputMethod.hide()
        platformUtilities.requestStoragePermission()

        var queue = []
        if (radioAll.checked) {
            for (var i = 0; i < fileTree.length; i++)
                queue.push(fileTree[i])
        } else {
            // Ne collecter que les nœuds de type "file" cochés
            for (var j = 0; j < fileListModel.count; j++) {
                var nd = fileListModel.get(j)
                if (nd.nodeType === "file" && nd.isSelected && nd.idx >= 0)
                    queue.push(fileTree[nd.idx])
            }
        }

        if (queue.length === 0) {
            mainWindow.displayToast(tr("ERR_NO_SEL"))
            return
        }

        downloadQueue  = queue
        totalFiles     = queue.length
        processedFiles = 0
        infoText.text  = ""

        // Recalculer baseDestPath au moment du téléchargement (projet peut avoir changé)
        baseDestPath = computeBaseDestPath()

      //  iface.logMessage("[GHD][START] ==== DÉBUT TÉLÉCHARGEMENT ====")
     //   iface.logMessage("[GHD][START] owner=" + getOwner() + " repo=" + getRepo()
                     //    + " branch=" + getBranch())
      //  iface.logMessage("[GHD][START] baseDestPath=" + baseDestPath)
     //   iface.logMessage("[GHD][START] nbFichiers=" + queue.length)

        pluginState = "downloading"
        processNextFile()
    }

    function processNextFile() {
        if (downloadQueue.length === 0) {
            finishDownload()
            return
        }

        var item = downloadQueue[0]
        var info = "(" + (processedFiles + 1) + "/" + totalFiles + ")"
        statusText.text  = tr("STATUS_DL") + " " + info
        statusText.color = Theme.mainColor
        infoText.text    = item.path

        var destPath = buildDestPath(item.folder, item.filename)
        var dlUrl    = buildDownloadUrl(item.path)
        var tkn      = getToken()

      //  iface.logMessage("[GHD][DL] === Fichier " + info + " ===")
     //   iface.logMessage("[GHD][DL] path repo  : " + item.path)
      //  iface.logMessage("[GHD][DL] folder     : " + item.folder)
      //  iface.logMessage("[GHD][DL] filename   : " + item.filename)
     //   iface.logMessage("[GHD][DL] destPath   : " + destPath)
     //   iface.logMessage("[GHD][DL] dlUrl      : " + dlUrl)
     //   iface.logMessage("[GHD][DL] token set  : " + (tkn !== ""))

        // Crée récursivement les sous-dossiers nécessaires avant d'écrire
        ensureDir(item.folder)

        downloadSmartFile(dlUrl, destPath, tkn, function() {
        //    iface.logMessage("[GHD][DL] ✓ succès : " + item.filename)
            processedFiles++
            downloadQueue.shift()
            // Pause 600 ms entre fichiers pour respecter le rate-limit de l'API GitHub
            Qt.callLater(function() {
                Qt.createQmlObject(
                    'import QtQuick; Timer { interval: 600; repeat: false; running: true;' +
                    '  onTriggered: { ghDownloader.processNextFile(); destroy(); } }',
                    ghDownloader
                )
            })
        })
    }

    // ensureDir : crée récursivement les dossiers via platformUtilities.createDir()
    // Principe : partir de applicationDirectory() (le seul dossier garanti accessible)
    // et descendre niveau par niveau en appelant createDir(parent, enfant).
    // Le paramètre `path` de createDir ne doit jamais contenir de partie inexistante.
    function ensureDir(subFolder) {
        var appDir = platformUtilities.applicationDirectory()
     //   iface.logMessage("[GHD][DIR] appDir=" + appDir)

        // Construire la liste complète des segments à créer depuis appDir
        // baseDestPath = appDir + "/Imported Projects/" + folderName [+ "/subFolder"]
        // On retire le préfixe appDir pour ne garder que les segments à créer
        var rel = baseDestPath
        if (rel.indexOf(appDir) === 0) rel = rel.substring(appDir.length)
        // Supprimer le slash initial
        if (rel.charAt(0) === "/") rel = rel.substring(1)

        // Ajouter les segments du sous-dossier si présents
        if (subFolder && subFolder !== "") rel = rel + "/" + subFolder

        var segments = rel.split("/")
        var current  = appDir

        for (var i = 0; i < segments.length; i++) {
            var seg = segments[i]
            if (!seg) continue
            var target = current + "/" + seg
            // Ne créer que si absent (createDir retourne false si déjà existant
            // sur certaines versions — on vérifie d'abord)
            if (!FileUtils.fileExists(target)) {
                var ok = platformUtilities.createDir(current, seg)
            //    iface.logMessage("[GHD][DIR] createDir(" + current + ", " + seg
                             //    + ") → " + ok + " exists=" + FileUtils.fileExists(target))
            } else {
           //     iface.logMessage("[GHD][DIR] existe déjà : " + target)
            }
            current = target
        }
      //  iface.logMessage("[GHD][DIR] chemin final exists=" + FileUtils.fileExists(current))
    }

    // Téléchargement intelligent : sonde d'abord en texte pour détecter
    // un pointeur Git-LFS, puis reroutage selon le résultat.
    // NOTE : pas de responseType="arraybuffer" ici — on a besoin de responseText.
    function downloadSmartFile(url, destPath, token, onFinished) {
     //   iface.logMessage("[GHD][SMART] GET sonde : " + url)
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        // Accept TOUJOURS positionné — sinon GitHub renvoie un JSON base64
        xhr.setRequestHeader("Accept", "application/vnd.github.v3.raw")
        if (token !== "") xhr.setRequestHeader("Authorization", "Bearer " + token)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
          //  iface.logMessage("[GHD][SMART] status=" + xhr.status + " url=" + url)
            if (xhr.status === 200 || xhr.status === 0) {
                var head = xhr.responseText.substring(0, 300)
            //    iface.logMessage("[GHD][SMART] head300=" + head.substring(0, 80))
                if (head.indexOf("version https://git-lfs.github.com") === 0) {
              //      iface.logMessage("[GHD][SMART] → route LFS")
                    var oidMatch  = head.match(/oid sha256:([a-f0-9]+)/)
                    var sizeMatch = head.match(/size ([0-9]+)/)
                    if (oidMatch && sizeMatch) {
                        fetchLfsBlob(oidMatch[1], parseInt(sizeMatch[1]),
                                     destPath, token, onFinished)
                    } else {
                        abortDownload(tr("ERR_LFS") + " (parse pointer)")
                    }
                } else {
                //    iface.logMessage("[GHD][SMART] → binaire direct")
                    downloadDirectBinary(url, destPath, token, onFinished)
                }
            } else if (xhr.status === 429 || xhr.status === 403) {
                abortDownload(tr("ERR_HTTP") + " " + xhr.status
                              + " — rate-limit. Patientez puis réessayez.")
            } else {
                abortDownload(tr("ERR_HTTP") + " " + xhr.status + " url=" + url)
            }
        }
        xhr.send()
    }

    // Résolution LFS : POST au batch-endpoint → URL CDN réelle
    function fetchLfsBlob(oid, size, destPath, token, onFinished) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", getRepoLfsUrl())
        if (token !== "") xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Accept", "application/vnd.git-lfs+json")
        var payload = {
            "operation": "download",
            "transfers": ["basic"],
            "objects": [{ "oid": oid, "size": size }]
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr.status === 200) {
                try {
                    var r = JSON.parse(xhr.responseText)
                    downloadS3File(r.objects[0].actions.download.href, destPath, onFinished)
                } catch(e) {
                    abortDownload(tr("ERR_LFS") + " (parse batch)")
                }
            } else {
                abortDownload(tr("ERR_LFS") + " HTTP " + xhr.status)
            }
        }
        xhr.send(JSON.stringify(payload))
    }

    // Téléchargement depuis l'URL CDN/S3 fournie par le batch LFS (sans auth)
    function downloadS3File(url, destPath, onFinished) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.responseType = "arraybuffer"
        handleBinaryWrite(xhr, destPath, onFinished)
        xhr.send()
    }

    // Téléchargement binaire direct depuis l'API GitHub.
    // IMPORTANT : Accept TOUJOURS positionné, token optionnel.
    // Sans Accept: vnd.github.v3.raw, GitHub renvoie un JSON base64
    // au lieu des octets bruts — le fichier écrit serait illisible.
    function downloadDirectBinary(url, destPath, token, onFinished) {
     //   iface.logMessage("[GHD][BIN] GET binaire : " + url)
     //   iface.logMessage("[GHD][BIN] dest        : " + destPath)
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.responseType = "arraybuffer"
        // Accept TOUJOURS — obligatoire pour obtenir les octets bruts
        xhr.setRequestHeader("Accept", "application/vnd.github.v3.raw")
        if (token !== "") xhr.setRequestHeader("Authorization", "Bearer " + token)
        handleBinaryWrite(xhr, destPath, onFinished)
        xhr.send()
    }

    // Écriture sur disque en deux temps :
    //
    // PROBLÈME : FileUtils.writeFileContent vérifie isWithinProjectDirectory()
    // qui autorise uniquement les chemins dans qgisProject.homePath (projet
    // actuellement chargé). Si on télécharge dans un AUTRE dossier que le
    // projet ouvert → toujours false, même si le dossier existe.
    //
    // SOLUTION :
    //   1. Écrire dans homePath (autorisé) sous un nom temporaire .ghd_tmp
    //   2. Déplacer vers la destination finale via platformUtilities.renameFile()
    //      qui est un simple rename/move OS sans restriction de chemin.
    //
    // Si homePath est vide (aucun projet chargé), on écrit directement dans
    // la destination (peut fonctionner dans ce cas).
    function handleBinaryWrite(xhr, destPath, onFinished) {
        var rawPath   = destPath.toString()
        if (rawPath.indexOf("file://") === 0) rawPath = rawPath.substring(7)
        var cleanPath = decodeURIComponent(rawPath)

        var isGpkg    = cleanPath.toLowerCase().endsWith(".gpkg")
        // Pour les GPKG : destination finale via .part + swap atomique
        var finalPath = cleanPath
        var partPath  = cleanPath + ".part"

      //  iface.logMessage("[GHD][WRITE] cleanPath=" + cleanPath)
     //   iface.logMessage("[GHD][WRITE] isGpkg=" + isGpkg)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
         //   iface.logMessage("[GHD][WRITE] GET status=" + xhr.status
                        //     + " byteLength=" + (xhr.response ? xhr.response.byteLength : "null"))

            if (xhr.status === 200 || xhr.status === 0) {

                if (!xhr.response || xhr.response.byteLength === 0) {
                    abortDownload("Réponse vide (0 octets) : " + FileUtils.fileName(cleanPath))
                    return
                }

                // Vérification magic bytes pour les GeoPackages SQLite
                if (isGpkg) {
                    var arr = new Uint8Array(xhr.response.slice(0, 16))
                    var hdr = ""
                    for (var i = 0; i < arr.length; i++) hdr += String.fromCharCode(arr[i])
                  //  iface.logMessage("[GHD][WRITE] magic bytes : " + hdr.substring(0, 16))
                    if (hdr.indexOf("SQLite format 3") === -1) {
                        abortDownload(tr("ERR_GPKG") + " : " + FileUtils.fileName(cleanPath))
                        return
                    }
                }

                // ── Choisir le chemin d'écriture temporaire ───────────────
                // Extraire le homePath propre (sans file://)
                var home = qgisProject.homePath ? qgisProject.homePath.toString() : ""
                if (home.indexOf("file://") === 0) home = home.substring(7)
                home = decodeURIComponent(home)

                // Nom de fichier unique pour éviter les collisions entre fichiers
                var fileName  = FileUtils.fileName(cleanPath)
                var tmpName   = ".ghd_tmp_" + fileName
                // Écrire dans homePath si disponible, sinon directement dans la dest
                var writePath = (home !== "") ? (home + "/" + tmpName) : (isGpkg ? partPath : cleanPath)

               // iface.logMessage("[GHD][WRITE] home=" + home)
               // iface.logMessage("[GHD][WRITE] writePath (tmp)=" + writePath)

                var ok = FileUtils.writeFileContent(writePath, xhr.response)
               // iface.logMessage("[GHD][WRITE] writeFileContent=" + ok + " → " + writePath)

                if (!ok) {
                    abortDownload(tr("ERR_DISK") + " (écriture tmp) : " + fileName)
                    return
                }

                if (home !== "") {
                    // ── Déplacer depuis homePath vers la destination finale ──
                    // renameFile = rename OS sans restriction de chemin QField
                    var moveDest = isGpkg ? partPath : finalPath
                    var moved = platformUtilities.renameFile(writePath, moveDest, true)
                  //  iface.logMessage("[GHD][WRITE] renameFile → " + moveDest + " = " + moved)

                    if (!moved) {
                        abortDownload(tr("ERR_DISK") + " (déplacement) : " + fileName)
                        return
                    }
                }

                // ── Swap atomique pour les GPKG ───────────────────────────
                if (isGpkg) {
                    var swapped = performSafeFileSwap(finalPath, partPath)
                   // iface.logMessage("[GHD][WRITE] swap gpkg=" + swapped)
                    if (swapped) {
                        if (onFinished) onFinished()
                    } else {
                        abortDownload(tr("ERR_DISK") + " (swap) : " + fileName)
                    }
                } else {
                    if (onFinished) onFinished()
                }

            } else {
                abortDownload(tr("ERR_HTTP") + " " + xhr.status + " : "
                              + FileUtils.fileName(cleanPath))
            }
        }
    }

    // Remplacement atomique d'un fichier GPKG existant :
    //   1. verrous WAL → backup
    //   2. original → .old
    //   3. .part → original
    //   4. nettoyage .old et wal backup
    function performSafeFileSwap(finalPath, tempPath) {
        var backupPath = finalPath + ".old"
        var walPath    = finalPath + "-wal"
        var shmPath    = finalPath + "-shm"
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
       // iface.logMessage("[GHD][ABORT] " + msg)
        pluginState      = "ready"
        statusText.text  = "❌  " + msg
        statusText.color = "red"
        infoText.text    = ""
    }

    function finishDownload() {
        pluginState      = "done"
        statusText.text  = tr("STATUS_DONE")
        statusText.color = "#80cc28"
        infoText.text    = tr("INFO_DONE")
    }

    // Cherche le premier .qgz / .qgs à la racine du projet téléchargé
    function findRootProjectFile() {
        for (var i = 0; i < fileTree.length; i++) {
            var fn = fileTree[i].filename.toLowerCase()
            if ((fn.endsWith(".qgz") || fn.endsWith(".qgs"))
                    && fileTree[i].folder === "") {
                return baseDestPath + "/" + fileTree[i].filename
            }
        }
        return ""
    }

    // =========================================================================
    // 9. COMPOSANT MARQUEE TEXTFIELD
    // Champ avec défilement automatique du texte long (hors focus)
    // =========================================================================

    component MarqueeTextField : TextField {
        id: mCtrl
        property color normalColor: "black"
        color: activeFocus ? normalColor : "transparent"
        clip:  true
        Layout.preferredHeight: Math.max(40, contentHeight + topPadding + bottomPadding + 14)
        verticalAlignment: TextInput.AlignVCenter

        Item {
            id: mContainer
            anchors.fill:         parent
            anchors.leftMargin:   mCtrl.leftPadding
            anchors.rightMargin:  mCtrl.rightPadding
            anchors.topMargin:    mCtrl.topPadding
            anchors.bottomMargin: mCtrl.bottomPadding
            visible: !mCtrl.activeFocus
            clip:    true

            Text {
                id: mScrollText
                text:             mCtrl.text
                font:             mCtrl.font
                color:            mCtrl.normalColor
                verticalAlignment: Text.AlignVCenter
                height:           parent.height
                x: 0
                property bool needsScroll:    width > mContainer.width
                property int  travelDistance: Math.max(0, width - mContainer.width)

                SequentialAnimation on x {
                    running: mScrollText.needsScroll && mContainer.visible
                    loops:   Animation.Infinite
                    PauseAnimation  { duration: 2000 }
                    NumberAnimation {
                        to:       -mScrollText.travelDistance
                        duration: mScrollText.travelDistance > 0
                                  ? mScrollText.travelDistance * 20 : 0
                        easing.type: Easing.Linear
                    }
                    PauseAnimation  { duration: 1000 }
                    NumberAnimation {
                        to:       0
                        duration: mScrollText.travelDistance > 0
                                  ? mScrollText.travelDistance * 20 : 0
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    // =========================================================================
    // 10. DIALOGUE PRINCIPAL
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
    : Math.max(8, (parent.height - height) / 2 - 40)   // ← -40 DANS le Max

        standardButtons: Dialog.NoButton

        // Padding Dialog à 0 — les marges 10 px gauche/droite sont gérées
        // directement par mainCol (x:10, width: parent.width - 20)
        topPadding:    0
        bottomPadding: 0
        leftPadding:   0
        rightPadding:  0

        background: Rectangle {
            color:        "white"
            border.color: Theme.mainColor
            border.width: 2
            radius:       8
        }

        contentItem: Flickable {
            id:             mainFlickable
            clip:           true
            contentWidth:   width
            contentHeight:  mainCol.y + mainCol.height + 6
            boundsBehavior: Flickable.StopAtBounds

            // FocusScope silencieux : forcer la perte de focus / cacher le clavier
            FocusScope {
                id:     dummyFocus
                width:  1
                height: 1
                z:      -1
            }

            MouseArea {
    width:  mainFlickable.contentWidth
    height: mainFlickable.contentHeight
    propagateComposedEvents: true   // ← laisse les gestes de scroll traverser
    onClicked: { dummyFocus.forceActiveFocus(); Qt.inputMethod.hide() }
}

            // ── COLONNE PRINCIPALE ─────────────────────────────────────────
            ColumnLayout {
                id:     mainCol
                x:      10                            // marge gauche 10 px
                y:      6
                width:  mainFlickable.width - 20      // marge droite 10 px
                spacing: 4

                // ── TITRE ────────────────────────────────────────
                Label {
                    text:   tr("TITLE")
                    font.bold:        true
                    font.pointSize:   13
                    color:            Theme.mainColor
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 0
                    Layout.bottomMargin: 2
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

//====DESTINATION : CHECKBOXS PROJET ou PLUGIN===
                // Deux boutons radio-like mutuellement exclusifs.
                // visible:true explicite pour ne jamais être masqués.
                RowLayout {
                    Layout.fillWidth: true
                    visible: true
                    spacing: 6

//===============CHECKBOX PROJET==================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        height: 34
                        radius: 6
                        visible: true
                        color: destMode === "project"
                               ? Qt.rgba(Theme.mainColor.r, Theme.mainColor.g,
                                         Theme.mainColor.b, 0.18)
                               : "#f0f0f0"
                        border.color: destMode === "project" ? Theme.mainColor : "#ccc"
                        border.width: destMode === "project" ? 2 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            CheckBox {
                                id: cbProject
                                visible: true
                                // checked géré uniquement par destMode — pas de binding
                                // circulaire — onClicked met à jour destMode
                                checked: destMode === "project"
                                // Empêcher l'utilisateur de décocher (une seule active)
                                onClicked: {
                                    destMode = "project"
                                    folderInput.text = ""    // réaffiche le placeholder MonProjet
                                    baseDestPath = computeBaseDestPath()
                                }
                            }
                            Text {
                                text:           tr("CB_DEST_PROJECT")
                                font.pixelSize: 12
                                font.bold:      destMode === "project"
                                color:          destMode === "project"
                                                ? Theme.mainColor : "#555"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                destMode = "project"
                                folderInput.text = ""    // réaffiche le placeholder MonProjet
                                baseDestPath = computeBaseDestPath()
                            }
                        }
                    }

//==============CHECKBOX PLUGIN===================
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        height: 34
                        radius: 6
                        visible: true
                        color: destMode === "plugin"
                               ? Qt.rgba(Theme.mainColor.r, Theme.mainColor.g,
                                         Theme.mainColor.b, 0.18)
                               : "#f0f0f0"
                        border.color: destMode === "plugin" ? Theme.mainColor : "#ccc"
                        border.width: destMode === "plugin" ? 2 : 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            CheckBox {
                                id: cbPlugin
                                visible: true
                                checked: destMode === "plugin"
                                onClicked: {
                                    destMode = "plugin"
                                    // Nom dossier = nom du repo automatiquement
                                    if (getRepo() !== "") folderInput.text = getRepo()
                                    baseDestPath = computeBaseDestPath()
                                }
                            }
                            Text {
                                text:           tr("CB_DEST_PLUGIN")
                                font.pixelSize: 12
                                font.bold:      destMode === "plugin"
                                color:          destMode === "plugin"
                                                ? Theme.mainColor : "#555"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                destMode = "plugin"
                                if (getRepo() !== "") folderInput.text = getRepo()
                                baseDestPath = computeBaseDestPath()
                            }
                        }
                    }
                }

                // ── OWNER + REPO ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
//================ZONE DE SAISIE OWNER==========
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop   // aligne les deux colonnes par le haut
                        spacing: 1
                        Text { text: tr("LBL_OWNER"); Layout.bottomMargin: 10; color: "#666"; font.pixelSize: 11 }

                        // Auteur : ComboBox éditable avec placeholder — même style que repoCombo
                        ComboBox {
                            id: ownerCombo
                            editable: true
                            currentIndex: -1          // démarre vide → affiche le placeholder
                            model: pluginAuthors
                            Layout.fillWidth: true
                            Layout.bottomMargin: 5
// Même hauteur que MarqueeTextField pour aligner les deux colonnes
                            Layout.preferredHeight: Math.max(40, implicitContentHeight + topPadding + bottomPadding + 14)
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                            Component.onCompleted: {
                                // Injecter le placeholder dans le TextField interne
                                contentItem.placeholderText = tr("PH_OWNER")
                            }
                            // onActivated : sélection depuis la liste déroulante
                            onActivated: {
                                if (destMode === "plugin") {
                                    var repos = pluginsByAuthor[currentText.trim()]
                                    repoCombo.model = repos ? repos : []
                                    repoCombo.currentIndex = (repos && repos.length > 0) ? 0 : -1
                                    if (repos && repos.length > 0) folderInput.text = repos[0]
                                }
                            }
                            // onEditTextChanged : saisie libre
                            onEditTextChanged: {
                                if (destMode === "plugin") {
                                    var repos2 = pluginsByAuthor[editText.trim()]
                                    repoCombo.model = repos2 ? repos2 : []
                                    repoCombo.currentIndex = (repos2 && repos2.length > 0) ? 0 : -1
                                    if (repos2 && repos2.length > 0) folderInput.text = repos2[0]
                                }
                            }
                        }
                    }
//==============ZONE DE SAISIE REPO==============
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop   // aligne les deux colonnes par le haut
                        spacing: 1
                        Text { text: tr("LBL_REPO"); color: "#666"; font.pixelSize: 11 }

                        // Mode projet : saisie libre
                        MarqueeTextField {
                            id: repoInput
                            visible: destMode === "project"
                            placeholderText: tr("PH_REPO")
                            selectByMouse:   true
                            Layout.fillWidth: true
                            Layout.bottomMargin: 5
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                            onTextChanged: {
                                // En mode plugin, nom de dossier = nom du repo
                                if (destMode === "plugin") folderInput.text = text.trim()
                            }
                        }

                        // Mode plugin : liste déroulante repos filtrée par auteur + saisie libre
                        ComboBox {
                            id: repoCombo
                            visible: destMode === "plugin"
                            
                            editable: true
                            model: []
                            displayText: editText
                            Layout.fillWidth: true
                            Layout.topMargin: 10

// Même hauteur que MarqueeTextField pour aligner les deux colonnes
                            Layout.preferredHeight: Math.max(40, implicitContentHeight + topPadding + bottomPadding + 14)
                            enabled: pluginState !== "exploring" && pluginState !== "downloading"
                            onEditTextChanged: {
                                // Nom dossier = nom du repo automatiquement
                                if (destMode === "plugin") folderInput.text = editText.trim()
                            }
                        }
                    }
                }

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
                            text:            "main"
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
                        Text { text: tr("LBL_FOLDER"); color: "#666"; font.pixelSize: 11 }
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

                // ── TOKEN CHECKBOX ─────────────────────────────────────────
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
                            onClicked: {
                                if (useTokenCheckbox.enabled)
                                    useTokenCheckbox.checked = !useTokenCheckbox.checked
                            }
                        }
                    }
                }

                // ── TOKEN INPUT (masqué, sans correction auto) ─────────────
                MarqueeTextField {
                    id: tokenInput
                    visible:         useTokenCheckbox.checked
                    placeholderText: tr("PH_TOKEN")
                    echoMode:        TextInput.Password
                    selectByMouse:   true
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

                    background: Rectangle {
                        color:  exploreBtn.enabled ? Theme.mainColor : "#aaa"
                        radius: 6
                    }
                    contentItem: Text {
                        text:  parent.text
                        color: "white"
                        font.bold:      true
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: startExplore()
                }

                // ── RÉSUMÉ EXPLORATION ─────────────────────────────────────
                ColumnLayout {
                    visible: pluginState === "ready"
                             || pluginState === "downloading"
                             || pluginState === "done"
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text:      tr("LBL_FILES_FOUND") + "  " + fileTree.length
                        font.bold: true
                        font.pixelSize: 13
                        color:     "#222"
                    }
                    RowLayout {
                        spacing: 4
                        Text { text: tr("LBL_DEST"); color: "#888"; font.pixelSize: 11 }
                        Text {
                            text:      baseDestPath
                            font.bold: true
                            font.pixelSize: 11
                            color:     "#333"
                            elide:     Text.ElideLeft
                            Layout.fillWidth: true
                        }
                    }
                }

                // ── MODE DE TÉLÉCHARGEMENT ─────────────────────────────────
                ButtonGroup { id: dlModeGroup }

                ColumnLayout {
                    visible: pluginState === "ready" || pluginState === "done"
                    Layout.fillWidth: true
                    spacing: 0
                    Layout.topMargin: 2

                    RadioButton {
                        id:    radioAll
                        text:  tr("RADIO_ALL")
                        checked: true
                        ButtonGroup.group: dlModeGroup
                        enabled: pluginState !== "downloading"
                    }
                    RadioButton {
                        id:    radioCustom
                        text:  tr("RADIO_CUSTOM")
                        checked: false
                        ButtonGroup.group: dlModeGroup
                        enabled: pluginState !== "downloading"
                    }
                }

                // ── LISTE CHECKABLE DES FICHIERS DU REPO ──────────────────
                // Column (pas ColumnLayout) : gère correctement les enfants
                // avec height:0 sans ajouter de spacing entre eux.
                Column {
                    id: fileListSection
                    visible: (pluginState === "ready" || pluginState === "done")
                             && radioCustom.checked
                    width:   mainCol.width
                    spacing: 0
                    // Layout.preferredHeight suit la hauteur réelle de la Column
                    Layout.preferredHeight: implicitHeight
                    Layout.fillWidth: true
                    Layout.topMargin: 2

                    // ---- En-tête : tout sélectionner + label ----
                    Rectangle {
                        width:  parent.width
                        height: 42
                        color:  Theme.mainColor
                        radius: 3

                        // Row (pas RowLayout) + anchors.verticalCenter
                        // garantissent le centrage vertical de chaque enfant
                        Row {
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin:     4
                            anchors.rightMargin:    4
                            spacing: 4

                            CheckBox {
                                id: selectAllChk
                                anchors.verticalCenter: parent.verticalCenter
                                checked: false
                                onClicked: {
                                    for (var i = 0; i < fileListModel.count; i++) {
                                    //    if (fileListModel.get(i).nodeType === "file")
                                            fileListModel.setProperty(i, "isSelected", checked)
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:      tr("LBL_SEL_ALL")
                                color:     "white"
                                font.bold: true
                                font.pixelSize: 12
                                width:     parent.width - selectAllChk.width - 12
                                verticalAlignment: Text.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectAllChk.checked = !selectAllChk.checked
                                        for (var i = 0; i < fileListModel.count; i++) {
                                        //    if (fileListModel.get(i).nodeType === "file")
                                                fileListModel.setProperty(i, "isSelected", selectAllChk.checked)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ─── Arborescence repo : dossiers + fichiers ──────────────
                    // Items avec height:0 quand masqués → Column les empile sans
                    // espace résiduel, contrairement à ColumnLayout.
                    Repeater {
                        model: fileListModel
                        delegate: Item {
                            width:  fileListSection.width
                            // height:0 quand masqué → Column empile sans espace résiduel
                            height: model.visible
                                    ? (model.nodeType === "folder" ? 44 : 40)
                                    : 0
                            // clip: true essentiel — bloque le débordement quand height=0
                            clip: true

 //============ LIGNE DOSSIER ====================
                            Rectangle {
                                visible: model.nodeType === "folder" && model.visible
                                width:   parent.width
                                height:  44
                                color:   Qt.rgba(Theme.mainColor.r,
                                                 Theme.mainColor.g,
                                                 Theme.mainColor.b, 0.10)

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: Qt.rgba(Theme.mainColor.r,
                                                   Theme.mainColor.g,
                                                   Theme.mainColor.b, 0.30)
                                }

                                MouseArea {
                                    anchors.top:         parent.top
                                    anchors.bottom:      parent.bottom
                                    anchors.left:        parent.left
                                    anchors.right:       parent.right
                                    anchors.rightMargin: 48
                                    onClicked: ghDownloader.toggleFolder(model.nodeKey)
                                }

                                Item {
                                    x:      6 + model.depth * 14
                                    y:      0
                                    width:  parent.width - x - 6
                                    height: parent.height

                                    RowLayout {
                                        anchors.fill:        parent
                                        anchors.rightMargin: 2
                                        spacing: 4

                                        Text {
                                            text:  model.expanded ? "▼" : ">"   //"▶"
                                            font.pixelSize:    14
                                            color: "#000000"       //Theme.mainColor
                                            Layout.preferredWidth: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        Text {
                                            text:           model.expanded ? "📂" : "📁"
                                            font.pixelSize: 22
                                        }
                                        Text {
                                            text:      model.displayName
                                            font.bold: true
                                            font.pixelSize: 13
                                            color:     "#1a1a2e"
                                            elide:     Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        CheckBox {
                                            checked: model.isSelected
                                            onClicked: ghDownloader.setFolderSelected(
                                                model.nodeKey, checked)
                                        }
                                    }
                                }
                            }

 //============ LIGNE FICHIER ===================
                            Rectangle {
                                visible: model.nodeType === "file" && model.visible
                                width:   parent.width
                                height:  40
                                color:   (index % 2 === 0) ? "white" : "#f8f8f8"

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width; height: 1
                                    color: "#ececec"
                                }

                                Item {
                                    x:      6 + model.depth * 14
                                    y:      0
                                    width:  parent.width - x - 6
                                    height: parent.height

                                    RowLayout {
                                        anchors.fill:        parent
                                        anchors.rightMargin: 2
                                        spacing: 2

                                        Text {
                                            text:  "└"
                                            font.pixelSize: 11
                                            color: "#ccc"
                                            Layout.preferredWidth: 12
                                        }
                                        CheckBox {
                                            checked: model.isSelected
                                            onClicked: fileListModel.setProperty(
                                                index, "isSelected", checked)
                                        }
                                        Text {
                                            text: {
                                                var n = model.displayName.toLowerCase()
                                                if (n.endsWith(".gpkg")) return "🗄"
                                                if (n.endsWith(".qgz") || n.endsWith(".qgs"))
                                                    return "🗺"
                                                if (n.endsWith(".qml"))  return "📝"
                                                if (n.endsWith(".svg"))  return "🎨"
                                                if (n.endsWith(".pdf"))  return "📄"
                                                if (n.endsWith(".csv"))  return "📊"
                                                return "📎"
                                            }
                                            font.pixelSize: 13
                                        }
                                        Text {
                                            text:      model.displayName
                                            font.pixelSize: 12
                                            color:     "#222"
                                            elide:     Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text:  model.sizeLabel
                                            font.pixelSize: 11
                                            color: "#aaa"
                                            Layout.preferredWidth: 46
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    } // Repeater
                } // Column fileListSection

 // ── BARRE DE PROGRESSION ──────────────────────────────────
                ProgressBar {
                    Layout.fillWidth: true
                    visible: pluginState === "downloading"
                    // Progression déterminée : N fichiers traités / total
                    value: totalFiles > 0 ? processedFiles / totalFiles : 0
                    Layout.topMargin: 4
                }

                // ── TEXTE DE STATUT ────────────────────────────────────────
                Text {
                    id:             statusText
                    text:           ""
                    font.bold:      true
                    font.pixelSize: 12
                    wrapMode:       Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible:        text.length > 0
                    Layout.topMargin: 2
                }

                // ── TEXTE D'INFORMATION ────────────────────────────────────
                Text {
                    id:             infoText
                    text:           ""
                    font.pixelSize: 11
                    color:          "#555"
                    wrapMode:       Text.WordWrap
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible:        text.length > 0
                    elide:          Text.ElideLeft
                }

                // ── BOUTONS D'ACTION ───────────────────────────────────────
                // Centrage via Item (fillWidth) + Row (anchors.horizontalCenter).
                // IMPORTANT : ne jamais mettre visible:false sur un bouton dans un Row —
                // Qt Row conserve la place des éléments invisibles, décalant les autres.
                // Chaque combinaison d'état a son propre Item.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin:    4
                    Layout.bottomMargin: 2
                    spacing: 4

                    // ── État "ready" : Télécharger + Fermer ────────────────
                    Item {
                        Layout.fillWidth: true
                        height: 36
                        visible: pluginState === "ready"
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            Button {
                                height: 36
                                text: tr("BTN_DOWNLOAD")
                                background: Rectangle { color: Theme.mainColor; radius: 6 }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.bold: true; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: startDownload()
                            }
                            Button {
                                height: 36
                                text: tr("BTN_CLOSE")
                                background: Rectangle { color: "#888"; radius: 6 }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.bold: true; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: downloadDialog.close()
                            }
                        }
                    }

                    // ── États "config" / "exploring" : Fermer seul ─────────
                    Item {
                        Layout.fillWidth: true
                        height: 36
                        visible: pluginState === "config" || pluginState === "exploring"
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            Button {
                                height: 36
                                text: tr("BTN_CLOSE")
                                background: Rectangle { color: "#888"; radius: 6 }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.bold: true; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: downloadDialog.close()
                            }
                        }
                    }

                    // ── État "done" + projet : Mettre à jour + Ouvrir ──────
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
                                background: Rectangle { color: Theme.mainColor; radius: 6 }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.bold: true; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: {
                                    pluginState          = "ready"
                                    radioCustom.checked  = true
                                    statusText.text      = ""
                                    infoText.text        = ""
                                    selectAllChk.checked = false
                                    for (var i = 0; i < fileListModel.count; i++)
                                        fileListModel.setProperty(i, "isSelected", false)
                                }
                            }
                            Button {
                                height: 36
                                text: tr("BTN_OPEN")
                                background: Rectangle { color: "#80cc28"; radius: 6 }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.bold: true; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: {
                                    var projPath = findRootProjectFile()
                                    downloadDialog.close()
                                    if (projPath !== "") iface.loadFile(projPath)
                                }
                            }
                        }
                    }

                    // ── État "done" : Fermer seul (projet + plugin) ────────
                    Item {
                        Layout.fillWidth: true
                        height: 36
                        visible: pluginState === "done"
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            Button {
                                height: 36
                                text: tr("BTN_CLOSE")
                                background: Rectangle { color: "#888"; radius: 6 }
                                contentItem: Text {
                                    text: parent.text; color: "white"
                                    font.bold: true; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                onClicked: downloadDialog.close()
                            }
                        }
                    }

                } // ColumnLayout boutons
            } // ColumnLayout mainCol
        } // Flickable contentItem
    } // Dialog

} // Item ghDownloader
