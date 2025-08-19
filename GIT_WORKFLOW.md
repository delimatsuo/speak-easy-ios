# Git Workflow & Release Management

## 🌟 **Branching Strategy**

### **Production Branches**
- **`main`** - Production-ready code, always deployable
- **`develop`** - Integration branch for features, staging environment

### **Feature Branches**
- **`feature/feature-name`** - New features and improvements
- **`bugfix/issue-description`** - Bug fixes
- **`hotfix/critical-fix`** - Emergency production fixes

## 🚀 **Release Process**

### **1. Feature Development**
```bash
# Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/new-feature-name

# Work on feature, commit regularly
git add .
git commit -m "feat: Add new feature description"

# Push feature branch
git push -u origin feature/new-feature-name
```

### **2. Feature Integration**
```bash
# Merge feature to develop
git checkout develop
git pull origin develop
git merge feature/new-feature-name
git push origin develop

# Clean up feature branch
git branch -d feature/new-feature-name
git push origin --delete feature/new-feature-name
```

### **3. Production Release**
```bash
# Merge develop to main
git checkout main
git pull origin main
git merge develop
git push origin main

# Create release tag
git tag -a v1.x.x -m "Release description"
git push origin v1.x.x
```

## 🏷️ **Semantic Versioning**

### **Version Format: `vMAJOR.MINOR.PATCH`**

- **MAJOR** (v2.0.0) - Breaking changes, major rewrites
- **MINOR** (v1.2.0) - New features, backwards compatible
- **PATCH** (v1.1.1) - Bug fixes, small improvements

### **Current Version: v1.2.0**
✨ Features: Audio replay, translation sharing, recording optimization

## 📝 **Commit Message Convention**

### **Format**: `type(scope): description`

**Types:**
- `feat` - New feature
- `fix` - Bug fix  
- `perf` - Performance improvement
- `docs` - Documentation
- `style` - Formatting, no code change
- `refactor` - Code restructuring
- `test` - Adding tests
- `chore` - Maintenance tasks

**Examples:**
```bash
feat(audio): Add instant recording response
fix(share): Resolve translation sharing bug
perf(ui): Optimize microphone button speed
docs(readme): Update installation guide
```

## 🔄 **Branch Synchronization**

### **Keep Branches Updated**
```bash
# Sync develop with main (after production releases)
git checkout develop
git pull origin develop
git merge main
git push origin develop

# Update feature branch with latest develop
git checkout feature/my-feature
git pull origin develop
git rebase develop  # or merge develop
```

## 🧹 **Cleanup Commands**

### **Remove Merged Branches**
```bash
# List merged branches
git branch --merged

# Delete local merged branches
git branch -d feature/old-feature

# Delete remote branches
git push origin --delete feature/old-feature

# Clean up stale remote references
git remote prune origin
```

## 📊 **Current Repository State**

### **Active Branches:**
- ✅ `main` (production) - v1.2.0
- ✅ `develop` (staging) - synced with main
- 📚 `feature/example-new-feature` (documentation)

### **Recent Releases:**
- **v1.2.0** - Audio improvements & sharing feature
- Production-ready with full testing

## 🛡️ **Best Practices**

### **Development**
1. ✅ Always create feature branches from `develop`
2. ✅ Use descriptive branch and commit names
3. ✅ Test thoroughly before merging
4. ✅ Keep commits atomic and focused
5. ✅ Update documentation with changes

### **Releases**
1. ✅ Tag all production releases
2. ✅ Write detailed release notes
3. ✅ Test on staging before production
4. ✅ Keep main and develop synchronized
5. ✅ Clean up merged branches

### **Emergency Fixes**
```bash
# Hotfix from main
git checkout main
git checkout -b hotfix/critical-issue
# Fix and test
git checkout main
git merge hotfix/critical-issue
git tag -a v1.2.1 -m "Hotfix: Critical issue"
git push origin main v1.2.1

# Merge back to develop
git checkout develop
git merge main
git push origin develop
```

## 📞 **Team Coordination**

### **Before Starting Work**
- Pull latest `develop` branch
- Check if feature branch already exists
- Communicate with team about overlapping work

### **Before Merging**
- Ensure tests pass
- Code review if working with team
- Update documentation
- Verify no conflicts with main

---

**🎯 This workflow ensures:**
- Clean, organized codebase
- Proper release tracking
- Easy rollback capabilities
- Professional development process
