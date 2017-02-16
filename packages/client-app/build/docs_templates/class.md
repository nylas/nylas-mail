# {{ name }}

## Summary

{{{documentation.description}}}

<ul>
    {{#each documentation.sections}}
    <li><a href="#{{name}}">{{name}}</a></li>
    {{/each}}
</ul>


{{#if documentation.classProperties.length}}

### Class Properties

{{#each documentation.classProperties}}
{{> _property.html}}
{{/each}}

{{/if}}


{{#if documentation.classMethods.length}}

### Class Methods

{{#each documentation.classMethods}}
{{> _function.html}}
{{/each}}

{{/if}}


{{#if documentation.instanceMethods.length}}

### Instance Methods

{{#each documentation.instanceMethods}}
{{> _function.html}}
{{/each}}

{{/if}}
