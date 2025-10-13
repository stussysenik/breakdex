## 1. Diagnose Core Data Generation Issue
- [x] 1.1 Check Xcode Core Data code generation settings
- [x] 1.2 Verify .xcdatamodel file configuration
- [x] 1.3 Identify why properties aren't being generated

## 2. Fix Core Data Configuration
- [x] 2.1 Update code generation settings if needed
- [x] 2.2 Ensure proper entity attribute configuration
- [x] 2.3 Clean derived data and rebuild

## 3. Regenerate Core Data Classes
- [x] 3.1 Delete existing generated class files
- [x] 3.2 Create Move+CoreDataProperties.swift with all @NSManaged properties
- [x] 3.3 Verify all attributes have corresponding properties

## 4. Validate Build
- [x] 4.1 Test compilation of PersistenceBridge.swift
- [x] 4.2 Ensure learningState and photosIdentifier are accessible
- [ ] 4.3 Run full project build verification

## 5. Learning Lessons & Future Prevention
- [x] 5.1 **Core Data uses two-file generation**: Always check for BOTH {Entity}+CoreDataClass.swift AND {Entity}+CoreDataProperties.swift
- [x] 5.2 **Target membership is critical**: Generated files must be included in the build target
- [x] 5.3 **Visual model ≠ generated code**: Seeing attributes in Xcode model editor doesn't guarantee generated properties exist
- [x] 5.4 **Manual recovery pattern**: When properties are missing, manually create the Properties file with @NSManaged declarations
- [x] 5.5 **Consistent file patterns**: Follow the same structure as existing working entity properties files