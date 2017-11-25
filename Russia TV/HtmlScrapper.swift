//
//  HtmlScrapper.swift
//  Russia TV
//
//  Created by Сергей Сейтов on 02.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

import Foundation
import Foundation

class HtmlScrapper {
    
    // Queries in order of priority
    
    let descQueries : [(String, String?)] = [
        ("//head/meta[@name='description']",         "content"),
        ("//head/meta[@property='og:description']",  "content"),
        ("//head/meta[@name='twitter:description']", "content")
    ]
    
    let titleQueries : [(String, String?)] = [
        ("//head/title", nil),
        ("//head/meta[@name='title']",         "content"),
        ("//head/meta[@property='og:title']",  "content"),
        ("//head/meta[@name='twitter:title']", "content")
    ]
    
    let imageQueries : [(String, String?)] = [
        ("//head/meta[@property='og:image']",  "content"),
        ("//head/meta[@name='twitter:image']", "content"),
        ("//link[@rel='image_src']",           "href"),
        ("//head/meta[@name='thumbnail']",     "content")
    ]
    
    let keywordsQueries : [(String, String?)] = [
        ("//head/meta[@name='keywords']", "content"),
        ]
    
    let itemsQueries : [(String, String?)] = [
        ("//head/meta[@name='keywords']", "content"),
        ]
    
    let unlikely = "com(bx|ment|munity)|dis(qus|cuss)|e(xtra|[-]?mail)|foot|"
        + "header|menu|re(mark|ply)|rss|sh(are|outbox)|sponsor"
        + "a(d|ll|gegate|rchive|ttachment)|(pag(er|ination))|popup|print|"
        + "login|si(debar|gn|ngle)"
    
    let posetive = "(^(body|content|h?entry|main|page|post|text|blog|story|haupt))"
        + "|arti(cle|kel)|instapaper_body"
    
    let negative = "nav($|igation)|user|com(ment|bx)|(^com-)|contact|"
        + "foot|masthead|(me(dia|ta))|outbrain|promo|related|scroll|(sho(utbox|pping))|"
        + "sidebar|sponsor|tags|tool|widget|player|disclaimer|toc|infobox|vcard"
    
    let nodesTags = "p|div|td|h1|h2|article|section"
    
    var unlikelyRegExp : NSRegularExpression?
    var posetiveRegExp : NSRegularExpression?
    var negativeRegExp : NSRegularExpression?
    var nodesRegExp    : NSRegularExpression?
    
    
    private var document : GDataXMLDocument?
    private var maxWeight = 0
    private var maxWeightNode : GDataXMLElement?
    
    var maxWeightImgUrl : String?
    var maxWeightText   : String?
    
    
    private func weightNode(_ node : GDataXMLElement) -> Int {
        var weight = 0
        
        if let className = node.attribute(forName: "class")?.stringValue() {
            let classNameRange = NSMakeRange(0, className.count)
            if let posetiveRegExp = posetiveRegExp {
                if posetiveRegExp.matches(in: className, options: .reportProgress, range:classNameRange).count > 0 {
                    weight += 35
                }
            }
            
            if let unlikelyRegExp = unlikelyRegExp {
                if unlikelyRegExp.matches(in: className, options: .reportProgress, range:classNameRange).count > 0 {
                    weight -= 20
                }
            }
            
            if let negativeRegExp = negativeRegExp {
                if negativeRegExp.matches(in: className, options: .reportProgress, range:classNameRange).count > 0 {
                    weight -= 50
                }
            }
        }
        
        if let id = node.attribute(forName: "id")?.stringValue() {
            let idRange = NSMakeRange(0, id.count)
            if let posetiveRegExp = posetiveRegExp {
                if posetiveRegExp.matches(in: id, options: .reportProgress, range:idRange ).count > 0 {
                    weight += 40
                }
            }
            
            if let unlikelyRegExp = unlikelyRegExp {
                if unlikelyRegExp.matches(in: id, options: .reportProgress, range:idRange).count > 0 {
                    weight -= 20
                }
            }
            
            if let negativeRegExp = negativeRegExp {
                if negativeRegExp.matches(in: id, options: .reportProgress, range:idRange).count > 0 {
                    weight -= 50
                }
            }
        }
        
        if let style = node.attribute(forName:"style")?.stringValue() {
            if let negativeRegExp = negativeRegExp {
                if negativeRegExp.matches(in: style, options: .reportProgress, range:NSMakeRange(0, style.count)).count > 0 {
                    weight -= 50
                }
            }
        }
        
        return weight
    }
    
    private func calcWeightForChild(node : GDataXMLElement, ownText : String) -> Int {
        return 0
    }
    
    private func weightChildNodes(_ node : GDataXMLElement) -> Int {
        var weight = 0
        var pEls = [GDataXMLElement]()
        var caption : GDataXMLElement?
        
        if let children = node.children() {
            children.forEach { (childObj: Any) in
                if let childNode = childObj as? GDataXMLElement {
                    let text = childNode.stringValue()
                    let length = text!.count
                    if  length < 20 {
                        return
                    }
                    
                    if length > 200 {
                        weight += max(50, length / 10)
                    }
                    
                    let tagName = node.name()
                    if tagName == "h1" || tagName == "h2" {
                        weight += 30
                    }
                    else if tagName == "div" || tagName == "p" {
                        weight += calcWeightForChild(node: childNode, ownText: text!)
                        
                        if tagName == "p" && length > 50 {
                            pEls.append(childNode)
                        }
                        
                        if let className = node.attribute(forName: "class")?.stringValue() {
                            if className.lowercased() == "caption" {
                                caption = node
                            }
                        }
                    }
                }
                
                if caption != nil {
                    weight += 30
                }
                
                //                if pEls.count >= 2 {
                //                    children.forEach { (childObj: AnyObject) in
                //
                //                    }
                //                }
            }
        }
        
        return weight
    }
    
    private func importantNodes()->[GDataXMLElement]? {
        do {
            if let bodyNodes = try (document?.nodes(forXPath: "//body") as? [GDataXMLElement]) {
                if bodyNodes.count > 0 {
                    if let innerNodes = try bodyNodes[0].nodes(forXPath: "//*") as? [GDataXMLElement] {
                        //                        var score = 100
                        //                        var scoredNodes : [(GDataXMLElement, Int)]
                        //                        innerNodes.forEach { (innerNode : GDataXMLElement) in
                        //                            if let nodesRegExp = nodesRegExp {
                        //                                let tagName = innerNode.name()
                        //                                if nodesRegExp.matchesInString(tagName,
                        //                                    options: NSMatchingOptions.ReportProgress,
                        //                                    range:NSMakeRange(0, tagName.characters.count)).count > 0 {
                        //                                        scoredNodes.append((innerNode, score))
                        //                                        score /= 2
                        //                                }
                        //                            }
                        //                        }
                        //                        return scoredNodes
                        return innerNodes
                    }
                }
            }
        }
        catch _ {
            return nil
        }
        
        return nil
    }
    
    private func clearNode(_ node: GDataXMLElement) {
        do {
            if let scriptNodes = try (node.nodes(forXPath: "//script") as? [GDataXMLElement]) {
                scriptNodes.forEach { (scriptNode : GDataXMLElement) in
                    node.removeChild(scriptNode)
                }
            }
            
            if let noScriptNodes = try (node.nodes(forXPath: "//noscript") as? [GDataXMLElement]) {
                noScriptNodes.forEach { (noScriptNode : GDataXMLElement) in
                    node.removeChild(noScriptNode)
                }
            }
            
            if let styleNodes = try (node.nodes(forXPath: "//style") as? [GDataXMLElement]) {
                styleNodes.forEach { (styleNode : GDataXMLElement) in
                    node.removeChild(styleNode)
                }
            }
        }
        catch _ {
            
        }
    }
    
    private func findMaxWeightNode() {
        maxWeight = 0
        do {
            try unlikelyRegExp = NSRegularExpression(pattern: unlikely,  options: .caseInsensitive)
            try posetiveRegExp = NSRegularExpression(pattern: posetive,  options: .caseInsensitive)
            try negativeRegExp = NSRegularExpression(pattern: negative,  options: .caseInsensitive)
            try nodesRegExp    = NSRegularExpression(pattern: nodesTags, options: .caseInsensitive)
        }
        catch _ {
            NSLog("Error creating regular expressions")
            return
        }
        
        if let importantNodes = importantNodes() {
            importantNodes.forEach { (node: GDataXMLElement) in
                var weight = weightNode(node)
                weight += node.stringValue().count / 10
                weight += weightChildNodes(node)
                if ( weight > maxWeight )
                {
                    maxWeight = weight
                    maxWeightNode =  node
                }
                
            }
        }
    }
    
    private func sizeWeight(_ imgNode: GDataXMLElement) -> Int {
        var weight = 0
        if let widthStr = imgNode.attribute(forName: "width")?.stringValue() {
            if let width = Int(widthStr) {
                if width >= 50 {
                    weight += 20
                }
                else {
                    weight -= 20
                }
            }
        }
        
        if let heightStr = imgNode.attribute(forName: "height")?.stringValue() {
            if let height = Int(heightStr) {
                if height >= 50 {
                    weight += 20
                }
                else {
                    weight -= 20
                }
            }
        }
        
        return weight
    }
    
    private func altWeight(_ imgNode: GDataXMLElement) -> Int {
        var weight = 0
        if let altStr = imgNode.attribute(forName: "alt")?.stringValue() {
            if ( altStr.count > 35 ) {
                weight += 20
            }
        }
        
        return weight
    }
    
    private func titleWeight(_ imgNode: GDataXMLElement) -> Int {
        var weight = 0
        if let titleStr = imgNode.attribute(forName: "title")?.stringValue() {
            if ( titleStr.count > 35 ) {
                weight += 20
            }
        }
        
        return weight
    }
    
    // Bad filtering right now
    //    private func isAdImage(imgUrl: String) -> Bool {
    //        return imgUrl.componentsSeparatedByString("ad").count > 2
    //    }
    //
    
    private func determineImageSource(_ node :GDataXMLElement) -> GDataXMLElement? {
        
        var maxImgWeight = 20
        var maxImgNode : GDataXMLElement?
        
        do {
            if let imageNodes = try node.nodes(forXPath: "//img") as? [GDataXMLElement] {
                imageNodes.forEach { (imageNode : GDataXMLElement) in
                    //                    if let imageSource = imageNode.attributeForName("src")?.stringValue() {
                    //                        if isAdImage(imageSource) {
                    //                            return
                    //                        }
                    
                    let weight = sizeWeight(imageNode) +
                        altWeight(imageNode) +
                        titleWeight(imageNode)
                    
                    if weight > maxImgWeight {
                        maxImgWeight = weight
                        maxImgNode   = imageNode
                    }
                    //                    }
                }
            }
        }
        catch _ {
            
        }
        
        return maxImgNode
    }
    
    private func extractText(_ node :GDataXMLElement) -> String?
    {
        clearNode(node)
        
        let texts = (node.stringValue() as NSString).replacingOccurrences(of: "\t", with:"").components(separatedBy: .newlines)
        var importantTexts = [String]()
        texts.forEach({ (text: String) in
            let length = text.count
            if length > 140 {
                importantTexts.append(text)
            }
        })
        return importantTexts.first
    }
    
    init(data htmlData: Data)
    {
        do {
            try document = GDataXMLDocument(htmlData:htmlData)
        }
        catch {
            NSLog("Error parsing html data")
            return
        }
        
        findMaxWeightNode()
        if let maxWeightNode = maxWeightNode {
            
            // Images
            if let imageNode = determineImageSource(maxWeightNode) {
                maxWeightImgUrl = imageNode.attribute(forName: "src")?.stringValue()
            }
            
            // Text
            maxWeightText = extractText(maxWeightNode)
        }
    }
    
    private func extractValueUsing(_ document:GDataXMLDocument, path:String, attribute:String?) -> String? {
        do {
            let nodes = try document.nodes(forXPath: path)
            if  nodes.count == 0 {
                return nil
            }
            
            if let node = nodes[0] as? GDataXMLElement {
                
                // Valid attribute
                if let attribute = attribute {
                    if let attrNode = node.attribute(forName: attribute) {
                        return attrNode.stringValue()
                    }
                }
                    // Not using attribute
                else {
                    return node.stringValue()
                }
            }
        }
            
        catch _ {
            return nil
        }
        
        return nil
    }
    
    private func extractValuesUsing(_ document:GDataXMLDocument, path:String, attribute:String?) -> [String]? {
        var values : [String]?
        
        do {
            if let nodes = try document.nodes(forXPath: path) as? [GDataXMLElement] {
                values = [String]()
                nodes.forEach{ (nodeObj:AnyObject) in
                    if let node = nodeObj as? GDataXMLElement {
                        if let attribute = attribute {
                            if let value = node.attribute(forName: attribute)?.stringValue() {
                                values?.append(value)
                            }
                        }
                        else {
                            values?.append(node.stringValue())
                        }
                    }
                }
            }
        }
        catch _ {
            return values
        }
        
        return values
    }
    
    private func extractValueUsing(_ document:GDataXMLDocument, queries:[(String, String?)]) -> String? {
        for query in queries {
            if let value = extractValueUsing(document, path: query.0, attribute:query.1) {
                return value
            }
        }
        
        return nil
    }
    
    private func extractValuesUsing(_ document:GDataXMLDocument, queries:[(String, String?)]) -> [String]? {
        for query in queries {
            if let values = extractValuesUsing(document, path: query.0, attribute:query.1) {
                return values
            }
        }
        
        return nil
    }
    
    func title()->String?
    {
        if let document = document {
            return extractValueUsing(document, queries:titleQueries)
        }
        
        return nil
    }
    
    func description()->String?
    {
        if let document = document {
            if let description = extractValueUsing(document, queries:descQueries) {
                return description
            }
        }
        
        return maxWeightText
    }
    
    func imageUrl()->String?
    {
        if let document = document {
            if let imageUrl =  extractValueUsing(document, queries:imageQueries) {
                return imageUrl
            }
        }
        
        return maxWeightImgUrl
    }
    
    func keywords()->[String]?
    {
        if let document = document {
            if let values = extractValuesUsing(document, queries:keywordsQueries) {
                var keywords = [String]()
                values.forEach{ (value : String) in
                    keywords.append(contentsOf:(value as NSString).components(separatedBy: .whitespacesAndNewlines))
                }
                return keywords
            }
        }
        
        return nil
    }
/*
    private func extractElementsUsing(_ document:GDataXMLDocument, path:String, attrName:String?, attrValue:String) -> [GDataXMLElement]?
    {
        var elements : [GDataXMLElement]?
        
        do {
            if let nodes = try document.nodes(forXPath: path) as? [GDataXMLElement] {
                elements = [GDataXMLElement]()
                nodes.forEach{ (nodeObj:AnyObject) in
                    if let node = nodeObj as? GDataXMLElement {
                        if let value = node.attribute(forName: attrName)?.stringValue() {
                            if value == attrValue {
                                elements?.append(node)
                            }
                        }
                    }
                }
            }
        }
        catch _ {
            return elements
        }
        
        return elements
    }
 */
    private func extractNodesUsing(_ document:GDataXMLDocument, path:String, attribute:String?) -> [GDataXMLElement]? {
        var values : [GDataXMLElement]?
        
        do {
            if let nodes = try document.nodes(forXPath: path) as? [GDataXMLElement] {
                values = [GDataXMLElement]()
                nodes.forEach{ (nodeObj:AnyObject) in
                    if let node = nodeObj as? GDataXMLElement {
                        if node.attribute(forName: attribute) != nil {
                            values?.append(node)
                        }
                    }
                }
            }
        }
        catch _ {
            return values
        }
        
        return values
    }

    private func nodeChildWithAttribute(_ node: GDataXMLElement, attrName:String? , attrValue:String) -> GDataXMLElement? {
        if let attribute = node.attribute(forName: attrName) {
            if attribute.stringValue() == attrValue {
//                print("\(attribute) - \(attribute.stringValue())")
                return node
            }
        }
        if let childs = node.children() {
            for child in childs {
                if let childNode = child as? GDataXMLElement {
                    if let target = nodeChildWithAttribute(childNode, attrName: attrName, attrValue: attrValue) {
                        return target
                    }
                }
            }
            return nil
        } else {
            return nil
        }
    }
    
    func videoChannels()->[Channel] {
        
        if let document = document {
            if let nodes = extractNodesUsing(document, path: "//div", attribute: "data-context-item-id") {
                var channels:[Channel] = []
                for node in nodes {
                    if let id = node.attribute(forName: "data-context-item-id").stringValue() {
                        let channel = Channel()
                        let urlString = "https://www.youtube.com/watch?v=\(id)"
                        channel.channelURL = URL(string: urlString)
                        if let titleNode = nodeChildWithAttribute(node, attrName: "class", attrValue: "yt-uix-sessionlink yt-uix-tile-link  spf-link  yt-ui-ellipsis yt-ui-ellipsis-2") {
                            channel.channelTitle = titleNode.attribute(forName: "title").stringValue()
                        }
                        if let thumbNode = nodeChildWithAttribute(node, attrName: "class", attrValue: "yt-lockup-thumbnail") {
                            if let clip = nodeChildWithAttribute(thumbNode, attrName: "class", attrValue: "yt-thumb-clip") {
                                if let images = clip.elements(forName: "img") {
                                    if images.count > 0 {
                                        if let thumb = images[0] as? GDataXMLElement {
                                            if let attr = thumb.attribute(forName: "src") {
                                                if let thumbStr = attr.stringValue() {
                                                    let comps = thumbStr.components(separatedBy: "?")
                                                    if comps.count > 0 {
                                                        channel.channelThumb = URL(string: comps[0])
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if let metaNode = nodeChildWithAttribute(node, attrName: "class", attrValue: "yt-lockup-meta-info") {
                            if let childs = metaNode.children() {
                                var meta = ""
                                for item in childs {
                                    if let child = item as? GDataXMLNode {
                                        if let val = child.stringValue() {
                                            meta +=  "\(val) "
                                        }
                                    }
                                }
                                channel.channelMeta = meta
                            }
                        }
                        channels.append(channel)
                    }
                }
                
                return channels
            } else {
                return []
            }
        } else {
            return []
        }
    }
}
